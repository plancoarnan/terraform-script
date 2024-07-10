variable "repository_name" {
  description = "The name of the ECR repository."
  type        = string
  default = "everestappdcebfd55/nextappstackfunctione45a3c19repo"
}

variable "new_tag_name" {
  description = "The new tag name for the Docker image."
  type        = string
}

variable "dockerfile_path" {
  description = "Path to the Dockerfile."
  type        = string
  default = "."
}

variable "image_name" {
  description = "Name of the Docker image to build."
  type        = string
  default = "everestappdcebfd55/nextappstackfunctione45a3c19repo"
}

provider "aws" {
  region = "ap-southeast-1"  # Change the region as needed
}

data "aws_ecr_repository" "my_ecr" {
  name = var.repository_name
}


resource "null_resource" "docker_build_and_tag" {
  provisioner "local-exec" {
    command = <<EOT
      docker build -t ${var.image_name}:latest ${var.dockerfile_path}
      docker tag ${var.image_name}:latest ${data.aws_ecr_repository.my_ecr.repository_url}:${var.new_tag_name}
    EOT
  }

  depends_on = [data.aws_ecr_repository.my_ecr]
}

resource "null_resource" "docker_push" {
  provisioner "local-exec" {
    command = "docker push ${data.aws_ecr_repository.my_ecr.repository_url}:${var.new_tag_name}"
  }

  depends_on = [null_resource.docker_build_and_tag]
}
