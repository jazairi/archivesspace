require_relative 'indexer_common'
require 'net/http'

class RealtimeIndexer < CommonIndexer

  def initialize(backend_url)
    super

    @backend_url = backend_url
  end

  def get_updates(last_sequence = 0)
    response = do_http_request(URI.parse(@backend_url),
                               Net::HTTP::Get.new("/update-feed?last_sequence=#{last_sequence}"))

    if response.code != '200'
      raise "Indexing error: #{response.body}"
    end

    JSON.parse(response.body)
  end


  def run
    last_sequence = 0

    while true
      begin
        login

        # Blocks until something turns up
        updates = get_updates(last_sequence)

        if !updates.empty?

          # Pick out updates that represent deleted records
          deletes = updates.find_all { |update| update['record'] == 'deleted' }

          # Add the records that were created/updated
          index_records(updates - deletes)

          # Delete records that were deleted
          delete_records(deletes.map { |record| record['uri'] })

          send_commit(:soft)
          last_sequence = updates.last['sequence']
        end
      rescue Timeout::Error
        # Doesn't matter...
      rescue
        reset_session
        puts "#{$!.inspect}"
        puts $@.join("\n")
        sleep 5
      end
    end

  end

end
