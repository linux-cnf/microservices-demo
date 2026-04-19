terraform {
  backend "gcs" {
    bucket = "project-9e0b2bd9-4649-487c-9d1-tfstate"
    prefix = "live/main"
  }
}
