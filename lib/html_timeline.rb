module HtmlTimeline

  require './lib/gmail_sync'
  require 'haml'
  require 'active_support/all'
  require 'iconv'

  GRANULARITY = 15.minutes
  
  def self.run

    posts = GmailSync.read_posts
    raise "Borked. No posts to render" if posts.nil?
    posts = posts.sort { |a,b| a[:taken_at] <=> b[:taken_at] }


    #from_time =           posts[0][:taken_at].beginning_of_day
    from_time =           Time.parse('17 august 10:15')
    to_time =             posts[-1][:taken_at].end_of_day
    participants =        posts.map { |s| s[:taken_by] }.uniq


    # rating sorted participant buckets

    participant_shots = {}
    participants.each do |participant|
      participant_shots[participant] = posts.select { |s| s[:taken_by] == participant }.sort { |a,b| a[:rating] <=> b[:rating] }
    end

    participants.sort! { |b,a| participant_shots[a].length <=> participant_shots[b].length }


    # generate timestamps

    timestamps = []
    moving_time = from_time
    while moving_time < to_time
      timestamps << moving_time.to_s(:time)
      moving_time += GRANULARITY
    end

    # participant grid

    rows = []
    participants.each do |participant|
      moving_time = from_time
      columns = []
      while moving_time < to_time
        columns << posts.select do |post|
          post[:taken_by] == participant && post[:taken_at] > moving_time && post[:taken_at] < (moving_time + GRANULARITY)
        end
        moving_time += GRANULARITY
      end
      rows << columns
    end

    locals = {
      :rows => rows,
      :timestamps => timestamps,
      :participants => participants,
      :participant_shots => participant_shots,
      :posts => posts
    }

    engine = Haml::Engine.new(template, {:format => :html5})    
    html = engine.render(Object.new, locals)
    File.open('timeline.html', 'w:UTF-8') { |f| f.write(html) }
    `open timeline.html`
  end

  def self.template
<<-EOF 
!!! 5
%html{"encoding" => "utf-8"}
  %head
    %meta{'http-equiv' => 'Content-Type', :content => 'text/html', :charset => 'utf-8'}/
    %title
      Timeliner 
      = Time.now()
    %link{:href => 'style.css', :media => 'screen, print', :rel => 'stylesheet', :type => 'text/css'}/
  %body
    %h1
      = posts.length.to_s + " objects"
      = " found by " + participants.length.to_s + " participants"
    %table
      %thead
        %td
        - timestamps.each do |timestamp|
          %th= timestamp
      - rows.each_with_index do |row, i|
        %tr
          %th.name
            = participants[i]
            = "(" + participant_shots[participants[i]].length.to_s + ")"
          - row.each do |column|
            %td
              .outer_cell
                - column.each do |cell|
                  - if cell.is_a? Hash
                    .cell
                      .image
                        .rating
                          = cell[:rating]
                        = "<img src='" + cell[:filename].to_s + "'/>" 
                      .comment
                        = cell[:comment][0..40]
EOF
  end
end