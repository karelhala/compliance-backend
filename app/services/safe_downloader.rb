# frozen_string_literal: true

require 'open-uri'
require 'net/http'

# Service used to download reports or anything else. It includes
# protection against the infamous open('| ls')
class SafeDownloader
  DownloadError = Class.new(StandardError)

  DOWNLOAD_ERRORS = [
    SocketError,
    OpenURI::HTTPError,
    RuntimeError,
    URI::InvalidURIError,
    DownloadError
  ].freeze

  class << self
    def download(url, path, max_size: nil)
      url = encode_url(url)
      options = create_options(max_size)
      downloaded_file = url.open(options)
      patch_if_less_than_10k(downloaded_file)
      IO.copy_stream(downloaded_file, path) if path.present?
      downloaded_file
    rescue *DOWNLOAD_ERRORS => error
      raise DownloadError if error.instance_of?(RuntimeError) &&
                             error.message !~ /redirection/

      raise DownloadError, "download failed (#{url}): #{error.message}"
    end

    private

    def encode_url(url)
      url = URI(url)
      raise DownloadError, 'url was invalid' unless url.respond_to?(:open)

      url
    rescue ArgumentError
      raise DownloadError, 'url was invalid'
    end

    def patch_if_less_than_10k(downloaded_file)
      return downloaded_file unless downloaded_file.is_a?(StringIO)

      IO.copy_stream(downloaded_file, tempfile.path)
      downloaded_file = tempfile
      OpenURI::Meta.init downloaded_file, stringio
      downloaded_file
    end

    def create_options(max_size)
      options = {}
      options['User-Agent'] = 'Red Hat Insights: Compliance'
      options[:content_length_proc] = lambda do |size|
        if max_size && size && size > max_size
          raise Error, "file is too big (max is #{max_size})"
        end
      end
      options
    end
  end
end
