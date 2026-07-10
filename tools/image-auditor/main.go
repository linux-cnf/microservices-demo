package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strings"
	"text/tabwriter"
)

type PodList struct {
	Items []Pod `json:"items"`
}

type Pod struct {
	Metadata Metadata `json:"metadata"`
	Spec     PodSpec  `json:"spec"`
}

type Metadata struct {
	Namespace string `json:"namespace"`
	Name      string `json:"name"`
}

type PodSpec struct {
	InitContainers      []Container          `json:"initContainers"`
	Containers          []Container          `json:"containers"`
	EphemeralContainers []EphemeralContainer `json:"ephemeralContainers"`
}

type Container struct {
	Name  string `json:"name"`
	Image string `json:"image"`
}

type EphemeralContainer struct {
	Name  string `json:"name"`
	Image string `json:"image"`
}

type Finding struct {
	Namespace     string
	Pod           string
	ContainerType string
	Container     string
	Image         string
	Reason        string
}

func main() {
	allowedPrefixesArg := flag.String(
		"allowed-prefixes",
		"",
		"Comma-separated approved image prefixes. Example: us-central1-docker.pkg.dev/my-project/my-repo/",
	)
	namespace := flag.String(
		"namespace",
		"",
		"Scan only one namespace. Default: all namespaces",
	)
	showAllowed := flag.Bool(
		"show-allowed",
		false,
		"Show approved images as well as violations",
	)
	output := flag.String(
		"output",
		"table",
		"Output format: table or json",
	)
	flag.Parse()

	allowedPrefixes := parseAllowedPrefixes(*allowedPrefixesArg)
	if len(allowedPrefixes) == 0 {
		fmt.Fprintln(os.Stderr, "ERROR: At least one approved registry/repository prefix is required.")
		fmt.Fprintln(os.Stderr, "Example:")
		fmt.Fprintln(os.Stderr, `  go run image-auditor.go --allowed-prefixes "us-central1-docker.pkg.dev/project-id/microservices-demo/,us-central1-docker.pkg.dev/project-id/ai-microservices/"`)
		os.Exit(2)
	}

	pods, err := getPods(*namespace)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: unable to read pods: %v\n", err)
		os.Exit(3)
	}

	findings := scanPods(pods, allowedPrefixes, *showAllowed)

	sort.Slice(findings, func(i, j int) bool {
		if findings[i].Namespace != findings[j].Namespace {
			return findings[i].Namespace < findings[j].Namespace
		}
		if findings[i].Pod != findings[j].Pod {
			return findings[i].Pod < findings[j].Pod
		}
		return findings[i].Container < findings[j].Container
	})

	switch strings.ToLower(*output) {
	case "table":
		printTable(findings)
	case "json":
		if err := printJSON(findings); err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: unable to generate JSON: %v\n", err)
			os.Exit(2)
		}
	default:
		fmt.Fprintf(os.Stderr, "ERROR: unsupported output format %q. Use table or json.\n", *output)
		os.Exit(2)
	}

	violations := 0
	for _, finding := range findings {
		if finding.Reason != "ALLOWED" {
			violations++
		}
	}

	if violations > 0 {
		fmt.Fprintf(os.Stderr, "\nFound %d image violation(s).\n", violations)
		os.Exit(1)
	}

	fmt.Fprintln(os.Stderr, "\nNo unapproved images found.")
}

func getPods(namespace string) (PodList, error) {
	args := []string{"get", "pods"}

	if namespace == "" {
		args = append(args, "--all-namespaces")
	} else {
		args = append(args, "--namespace", namespace)
	}

	args = append(args, "-o", "json")

	cmd := exec.Command("kubectl", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return PodList{}, fmt.Errorf("kubectl failed: %s", strings.TrimSpace(string(output)))
	}

	var pods PodList
	if err := json.Unmarshal(output, &pods); err != nil {
		return PodList{}, fmt.Errorf("invalid kubectl JSON: %w", err)
	}

	return pods, nil
}

func scanPods(pods PodList, allowedPrefixes []string, showAllowed bool) []Finding {
	var findings []Finding

	for _, pod := range pods.Items {
		for _, container := range pod.Spec.InitContainers {
			findings = appendFinding(
				findings,
				pod,
				"initContainer",
				container.Name,
				container.Image,
				allowedPrefixes,
				showAllowed,
			)
		}

		for _, container := range pod.Spec.Containers {
			findings = appendFinding(
				findings,
				pod,
				"container",
				container.Name,
				container.Image,
				allowedPrefixes,
				showAllowed,
			)
		}

		for _, container := range pod.Spec.EphemeralContainers {
			findings = appendFinding(
				findings,
				pod,
				"ephemeralContainer",
				container.Name,
				container.Image,
				allowedPrefixes,
				showAllowed,
			)
		}
	}

	return findings
}

func appendFinding(
	findings []Finding,
	pod Pod,
	containerType string,
	containerName string,
	image string,
	allowedPrefixes []string,
	showAllowed bool,
) []Finding {
	allowed := isAllowed(image, allowedPrefixes)

	if allowed && !showAllowed {
		return findings
	}

	reason := "External or unapproved registry"
	if allowed {
		reason = "ALLOWED"
	}

	return append(findings, Finding{
		Namespace:     pod.Metadata.Namespace,
		Pod:           pod.Metadata.Name,
		ContainerType: containerType,
		Container:     containerName,
		Image:         image,
		Reason:        reason,
	})
}

func isAllowed(image string, allowedPrefixes []string) bool {
	normalizedImage := strings.TrimSpace(strings.ToLower(image))

	for _, prefix := range allowedPrefixes {
		if strings.HasPrefix(normalizedImage, strings.ToLower(prefix)) {
			return true
		}
	}

	return false
}

func parseAllowedPrefixes(value string) []string {
	var prefixes []string

	for _, prefix := range strings.Split(value, ",") {
		prefix = strings.TrimSpace(prefix)
		if prefix != "" {
			prefixes = append(prefixes, prefix)
		}
	}

	return prefixes
}

func printTable(findings []Finding) {
	if len(findings) == 0 {
		fmt.Println("No matching images found.")
		return
	}

	writer := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
	fmt.Fprintln(writer, "NAMESPACE\tPOD\tTYPE\tCONTAINER\tIMAGE\tRESULT")

	for _, finding := range findings {
		fmt.Fprintf(
			writer,
			"%s\t%s\t%s\t%s\t%s\t%s\n",
			finding.Namespace,
			finding.Pod,
			finding.ContainerType,
			finding.Container,
			finding.Image,
			finding.Reason,
		)
	}

	_ = writer.Flush()
}

func printJSON(findings []Finding) error {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	return encoder.Encode(findings)
}
