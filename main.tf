provider "aws" {
  region = "ap-southeast-2"  # Update with your desired AWS region
}

resource "aws_ecr_repository" "my_repo" {
  name = "everestwithtemplate"
  image_tag_mutability = "MUTABLE"
}

resource "null_resource" "sam_build" {
  depends_on = [aws_ecr_repository.my_repo]

  provisioner "local-exec" {
    command = <<EOT
      cd path_to_your_sam_app_directory
      sam build --template template.yaml --image-repository ${aws_ecr_repository.my_repo.repository_url}
    EOT
  }
}

resource "null_resource" "sam_deploy" {
  depends_on = [null_resource.sam_build]

  provisioner "local-exec" {
    command = <<EOT
      cd path_to_your_sam_app_directory
      sam deploy --template-file .aws-sam/build/template.yaml --stack-name my-sam-stack --capabilities CAPABILITY_IAM --image-repository ${aws_ecr_repository.my_repo.repository_url} --region us-east-1 --no-confirm-changeset
    EOT
  }
}