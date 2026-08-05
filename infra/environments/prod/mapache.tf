# Cold storage for Mapache telemetry. TCM-26's shelter uploader writes
# batch_<ulid>.parquet under <prefix>/<vehicle_id>/; gr26 lists the prefix
# and reads them back in via foreman ingest jobs.
#
# One shared key serves both sides. Writers and readers are therefore not
# separable: the on-car credential can overwrite an object as well as read
# it. Deletion is not granted, and keys are ULID-derived so an overwrite
# would need a ULID collision — but a per-consumer split is the fix if the
# car-side key ever leaves the team's hands.
resource "aws_s3_bucket" "mapache" {
  bucket = "gr-mapache"
}

resource "aws_s3_bucket_public_access_block" "mapache" {
  bucket = aws_s3_bucket.mapache.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_user" "mapache_prod" {
  name = "mapache-prod"
}

resource "aws_iam_access_key" "mapache_prod" {
  user = aws_iam_user.mapache_prod.name
}

resource "aws_iam_user_policy" "mapache_prod_s3" {
  name = "mapache-prod-s3"
  user = aws_iam_user.mapache_prod.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ]
        Resource = "${aws_s3_bucket.mapache.arn}/*"
      },
      # ListObjectsV2 authorizes against the bucket ARN, not the object ARN.
      # gr26's listShelterObjects pages the whole vehicle prefix, so without
      # this the ingest jobs fail with AccessDenied on an empty listing.
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.mapache.arn
      },
    ]
  })
}
