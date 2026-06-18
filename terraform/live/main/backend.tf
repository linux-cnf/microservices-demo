terraform {
  backend "gcs" {
    bucket = "project-19d98bfe-795f-49b8-af0-tfstate"
    prefix = "live/main"
  }
}
