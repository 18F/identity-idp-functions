require 'aws-sdk-s3'
require 'json'
require 'logger'

module IdentityIdpFunctions
  module DemoFunction
    def self.handle(event:, context:, logger: Logger.new(STDOUT))
      logger.info(event)

      s3_bucket_name = ENV["S3_BUCKET_NAME"]
      region = ENV["AWS_REGION"]

      s3 = Aws::S3::Resource.new(region: region)

      bucket = s3.bucket(s3_bucket_name)

      bucket.objects.limit(50).each do |item|
        logger.info(item.key)
      end
    end
  end
end
