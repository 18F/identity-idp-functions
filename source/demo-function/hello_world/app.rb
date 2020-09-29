require 'aws-sdk-s3'
require 'json'
require 'logger'

def lambda_handler(event:, context:)

  # Parameters
  # ----------
  # event: Hash, required
  
  # context: object, required
  #     Lambda Context runtime methods and attributes
  #     Context doc: https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html

  # Returns
  # ------
  logger = Logger.new(STDOUT)

  logger.info(event)
  
  s3_bucket_name = ENV["S3_BUCKET_NAME"]
  environment = ENV["ENVIRONMENT_NAME"]
  region = ENV["AWS_REGION"]
  kms_key_alias = ENV["KMS_KEY_ALIAS"]

  s3 = Aws::S3::Resource.new(region: region)

  bucket = s3.bucket(s3_bucket_name)

  bucket.objects.limit(50).each do |item|
    logger.info(item)
    print "Name: #{item.key}"
  end

  return
end

