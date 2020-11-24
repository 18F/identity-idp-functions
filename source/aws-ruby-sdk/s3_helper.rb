require 'aws-sdk-s3'

module IdentityIdpFunctions
  class S3Helper
    def download(url)
      uri = URI.parse(url)
      bucket = uri.host.gsub('.amazonaws.com', '')
      resp = s3_client.get_object(bucket: bucket, key: uri.path[1..-1])
      resp.body.read.b
    end

    def s3_client
      @s3_client ||= Aws::S3::Client.new(
        http_open_timeout: 5,
        http_read_timeout: 5,
      )
    end
  end
end
