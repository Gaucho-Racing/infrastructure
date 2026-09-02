resource "aws_s3_bucket" "depot_prod_usw2" {
  region = "us-west-2"
  bucket = "gr-depot-prod-usw2"
}

resource "aws_s3_bucket_public_access_block" "depot_prod_usw2" {
  region = "us-west-2"
  bucket = aws_s3_bucket.depot_prod_usw2.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "depot_prod_usw2" {
  region = "us-west-2"
  bucket = aws_s3_bucket.depot_prod_usw2.id

  cors_rule {
    allowed_origins = ["https://depot.gauchoracing.com"]
    allowed_methods = ["GET", "PUT", "HEAD"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket" "depot_prod_use1" {
  region = "us-east-1"
  bucket = "gr-depot-prod-use1"
}

resource "aws_s3_bucket_public_access_block" "depot_prod_use1" {
  region = "us-east-1"
  bucket = aws_s3_bucket.depot_prod_use1.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "depot_prod_use1" {
  region = "us-east-1"
  bucket = aws_s3_bucket.depot_prod_use1.id

  cors_rule {
    allowed_origins = ["https://depot.gauchoracing.com"]
    allowed_methods = ["GET", "PUT", "HEAD"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_iam_user" "depot_prod" {
  name = "depot-prod"
}

resource "aws_iam_access_key" "depot_prod" {
  user = aws_iam_user.depot_prod.name
}

resource "aws_iam_user_policy" "depot_prod_s3" {
  name = "depot-prod-s3"
  user = aws_iam_user.depot_prod.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ]
        Resource = [
          "${aws_s3_bucket.depot_prod_usw2.arn}/*",
          "${aws_s3_bucket.depot_prod_use1.arn}/*",
        ]
      }
    ]
  })
}
