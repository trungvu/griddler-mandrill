module Griddler
  module Mandrill
    class Adapter
      def initialize(params)
        @params = params
      end

      def self.normalize_params(params)
        adapter = new(params)
        adapter.normalize_params
      end

      def normalize_params
        events.map do |event|
          {
            to: recipients(:to, event),
            cc: recipients(:cc, event),
            from: full_email([ event[:from_email], event[:from_name] ]),
            subject: event[:subject],
            text: event.fetch(:text, ''),
            html: event.fetch(:html, ''),
            raw_body: event[:raw_msg],
            # headers: extract_headers(event[:headers]),
            headers: event[:raw_msg],
            attachments: attachment_files(event)
          }
        end
      end

      private

      attr_reader :params

      def events
        @events ||= ActiveSupport::JSON.decode(params[:mandrill_events]).map do |event|
          event['msg'].with_indifferent_access
        end
      end

      def recipients(field, event)
        Array.wrap(event[field]).map { |recipient| full_email(recipient) }
      end

      def full_email(contact_info)
        email = contact_info[0]
        if contact_info[1]
          "#{contact_info[1]} <#{email}>"
        else
          email
        end
      end

      def attachment_files(event)
        attachments = event[:attachments] || Array.new
        attachments.map do |key, attachment|
          ActionDispatch::Http::UploadedFile.new({
            filename: attachment[:name],
            type: attachment[:type],
            tempfile: create_tempfile(attachment)
          })
        end
      end

      def create_tempfile(attachment)
        filename = attachment[:name]
        tempfile = Tempfile.new(filename, Dir::tmpdir, encoding: 'ascii-8bit')
        content = attachment[:content]
        content = Base64.decode64(content) if attachment[:base64]
        tempfile.write(content)
        tempfile.rewind
        tempfile
      end


      # https://github.com/bradpauly/griddler-mailgun/blob/8d28854ea60e1604c46c1673a660f8ad6fc32c41/lib/griddler/mailgun/adapter.rb

        # Griddler expects unparsed headers to pass to ActionMailer, which will manually
        # unfold, split on line-endings, and parse into individual fields.
        #
        # Mailgun already provides fully-parsed headers in JSON -- so we're reconstructing
        # fake headers here for now, until we can find a better way to pass the parsed
        # headers directly to Griddler


      def extract_headers(input_headers)
        extracted_headers = {}
        if input_headers
          parsed_headers = JSON.parse(input_headers)
          parsed_headers.each{ |h| extracted_headers[h[0]] = h[1] }
        end
        new_headers = ActiveSupport::HashWithIndifferentAccess.new(extracted_headers)

        serialized = new_headers.to_a.collect { |header| "#{header[0]}: #{header[1]}" }.join("\n")

        puts "input_headers.inspect"
        puts input_headers.inspect
        puts serialized.inspect

        serialized
      end



    end
  end
end
