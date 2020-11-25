require 'aws-sdk-s3'

module IdentityIdpFunctions
  class S3Helper
    def download(url)
      uri = URI.parse(url)
      if uri.host.start_with?('s3.')
        _, bucket, key = uri.path.split('/')
      else
        bucket, *_rest = uri.host.split('.')
        _, key, *_rest = uri.path.split('/')
      end
      resp = s3_client.get_object(bucket: bucket, key: key)
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
