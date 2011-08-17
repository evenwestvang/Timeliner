# encoding: UTF-8

class GmailSync
  require 'gmail'
  require 'digest/sha1'
  require 'mini_magick'
  require 'exifr'
  
  USERNAME = '*'
  PASS = '*'

  def initialize
    @posts = GmailSync.read_posts()
  end

  def sync
    puts "\nSyncing unread mail – Logging in"
    Gmail.connect(USERNAME, PASS) do |gmail|
      gmail.inbox.emails(:unread).each do |email|

        from =    email.from.first
        subject = Mail::Encodings.value_decode(email.subject)
        rating =  subject.match(/(\d*)/)[0]
        comment = subject.match(/(\d?)[^a-zA-Z0-9]*(.*)/)[2]
        
        puts "Mail from #{from.name} / #{from.mailbox} @ #{email.date}"
        puts " - gives evaluation of #{rating} with comment '#{comment}'"
        puts " - with #{email.attachments.length} attachments"

        email.attachments.each do |attachment|
          print "  - '#{attachment.filename}'"
          print " attempting decode "
          begin
            image = MiniMagick::Image.read(attachment.decoded)
            
            format = image["format"].downcase
            print " *** #{format} *** "

            key = Digest::SHA1.hexdigest("#{from.name}_#{email.date}")[0..14]

            filename = "./data/attachments/#{key}.#{format}"
            print " looks like an image "
            print "- scaling & saving to #{filename} "

            image.resize "300x300"
            image.write(filename)
            
            taken_at = nil

            if format == "jpeg"
              print "looking for timestamp in exif – "

              exifr = EXIFR::JPEG.new(filename)
              taken_at = exifr.date_time

              if taken_at.nil?
                print "!no timestamp found in jpg. falling back to sent_at! "
              else
                print " exif found in timestamp - "
              end

              if exifr.orientation
                print "reorienting image "
                exifr.orientation.transform_rmagick(image)
                image.write(filename)
              end
            end
            taken_at ||= Time.parse(email.date)
            print "Taken at #{taken_at.to_s} "
            
            posting = {
              :taken_at =>    taken_at,
              :taken_by =>    Mail::Encodings.value_decode(from.name),
              :email =>       from.mailbox,
              :filename =>    filename,
              :rating =>      rating,
              :comment =>     comment
            }

            @posts << posting          
          
          rescue MiniMagick::Invalid
            puts "!!! ¡BOOM¡ - Could not decode image !!! "
          end
        end
      puts "\n\n"
      end
    end
    puts "\n\nDone"
    GmailSync.write_posts(@posts)
  end

  def self.mark_all_unread
    puts "Logging in"
    Gmail.connect(USERNAME, PASS) do |gmail|
      gmail.inbox.emails.each do |email|
        puts "Unreading #{email.inspect}"
        email.unread!
      end
    end
    puts "Finished"
  end

  private

  def self.read_posts
    posts = []
    begin
      posts = File.open('data/state', 'r:UTF-8') { |f| Marshal.load(f) }
    rescue IOError, Errno::ENOENT
      puts "Can't read state. Blank slate."
    end
    posts
  end

  def self.write_posts(posts)
    File.open('data/state', 'w:UTF-8') { |f| Marshal.dump(posts, f) }
  end
end
