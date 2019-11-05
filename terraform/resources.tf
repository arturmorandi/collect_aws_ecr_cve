resource "aws_iam_policy" "<ROLE_NAME>" {
  name = "<ROLE_NAME_WITH_S3_FULLACCESS_OR_CHANGE_TO_DESIRED_PERMISSION_LEVEL_BELOW>"
  path = "/"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListObjectsInBucket",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "<S3_BUCKET_ARN>"
            ]
        },
        {
            "Sid": "AllObjectActions",
            "Effect": "Allow",
            "Action": "s3:*Object",
            "Resource": [
                "<S3_BUCKET_ARN>/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "<ROLE_NAME>" {
  role = "<ROLE_ATTACHED_TO_YOUR_EC2_INSTANCE>"
  policy_arn = "${aws_iam_policy.<ROLE_NAME>.arn}"
  
}
