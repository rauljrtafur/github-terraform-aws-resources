variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "layer_lambda_pillow" {
  type    = string
  default = "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p39-pillow:1"
}

locals {
  routes = {
    "index" : {
      name : "index"
      http_verb : "GET"
      path = "/"
      policies : "logs:List*",
      resource : "arn:aws:logs:*:*:*"

    },
    "profile-get" : {
      name : "profile-get"
      http_verb : "GET"
      path = "/profile"
      policies : ["dynamodb:Scan"]
      resource : [aws_dynamodb_table.profile.arn]
    },
    "profile-post" : {
      name : "profile-post"
      http_verb : "POST"
      path = "/profile"
      policies : ["dynamodb:PutItem", "dynamodb:Scan"]
      resource : [aws_dynamodb_table.profile.arn]
    }
  }
}