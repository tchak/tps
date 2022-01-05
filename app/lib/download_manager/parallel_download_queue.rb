module DownloadManager
  class ParallelDownloadQueue
    include Utils::Retryable
    DOWNLOAD_MAX_PARALLEL = ENV.fetch('DOWNLOAD_MAX_PARALLEL') { 10 }

    attr_accessor :attachments,
                  :destination,
                  :on_error

    def initialize(attachments, destination)
      @attachments = attachments
      @destination = destination
    end

    def download_all
      hydra = Typhoeus::Hydra.new(max_concurrency: DOWNLOAD_MAX_PARALLEL)

      attachments.map do |attachment, path|
        begin
          with_retry(max_attempt: 1) do
            download_one(attachment: attachment,
                         path_in_download_dir: path,
                         http_client: hydra)
          end
        rescue => e
          on_error.call(attachment, path, e)
        end
      end
      hydra.run
    end

    # rubocop:disable Style/AutoResourceCleanup
    # can't be used with typhoeus, otherwise block is closed before the request is run by hydra
    def download_one(attachment:, path_in_download_dir:, http_client:)
      attachment_path = File.join(destination, path_in_download_dir)
      attachment_dir = File.dirname(attachment_path)

      FileUtils.mkdir_p(attachment_dir) if !Dir.exist?(attachment_dir) # defensive, do not write in undefined dir
      if attachment.is_a?(PiecesJustificativesService::FakeAttachment)
        File.write(attachment_path, attachment.file.read, mode: 'wb')
      else
        request = Typhoeus::Request.new(attachment.url)
        fd = File.open(attachment_path, mode: 'wb')
        request.on_body do |chunk|
          fd.write(chunk)
        end
        request.on_complete do |response|
          fd.close
          unless response.success?
            raise 'ko'
          end
        end
        http_client.queue(request)
      end
    rescue
      File.delete(attachment_path) if File.exist?(attachment_path) # -> case of retries failed, must cleanup partialy downloaded file
      raise
    end
    # rubocop:enable Style/AutoResourceCleanup
  end
end