class Timeliner < Thor
  desc "sync", "Synchronize with gmail"

  def sync
    require './lib/gmail_sync'
    GmailSync.new().sync
  end

  desc "generate", "Generate HTML from static files"
  def generate
    require './lib/html_timeline'
    HtmlTimeline.run
  end

  desc "clean", "Clear out static files "
  def clean
    `rm ./data/*`
    `rm ./data/attachments/*`
    require './lib/gmail_sync'
    GmailSync.mark_all_unread
  end

end