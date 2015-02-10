require 'sqlite3'
require 'mail'

module RubyMail
  class Client
    attr_accessor :password, :pop3, :pop3_port, :smtp, :smtp_port, :pop3_ssl, :smtp_ssl
    attr_writer :email

    def initialize(email, password = nil, pop3 = nil, pop3_port = nil, pop3_ssl = nil, smtp = nil, smtp_port = nil, smtp_ssl=nil)
      init_db
      if (password == nil)
        user_info = @database.execute("SELECT password, pop3, pop3_port, smtp, smtp_port, pop3_ssl, smtp_ssl FROM users WHERE email = ?", email).flatten
        password, pop3, pop3_port, smtp, smtp_port, pop3_ssl, smtp_ssl = user_info
      else
        @database.execute("INSERT INTO users VALUES(NULL, ?, ?, ?, ?, ?, ?, ?, ?)", email, password, pop3, pop3_port, smtp, smtp_port, pop3_ssl, smtp_ssl)
      end
      init_mail(email, password, pop3, pop3_port, pop3_ssl, smtp, smtp_port, smtp_ssl)
    end

    def init_db
      @database = SQLite3::Database.new("data.db")
      @database.execute "CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT, password TEXT, pop3 TEXT, pop3_port INTEGER, smtp TEXT, smtp_port INTEGER, pop3_ssl INTEGER, smtp_ssl INTEGER)"
      @database.execute "CREATE TABLE IF NOT EXISTS emails(id INTEGER PRIMARY KEY AUTOINCREMENT, message_id TEXT, text TEXT, html TEXT, [from] TEXT, [to] TEXT, subject TEXT, received TEXT, read INTEGER)"
      @database.execute "CREATE TABLE IF NOT EXISTS attachments(id INTEGER PRIMARY KEY AUTOINCREMENT, message_id TEXT, file_name TEXT, attachment BLOB)"
    end

    def init_mail(email, password, pop3, pop3_port, pop3_ssl, smtp, smtp_port, smtp_ssl)
      @email, @password, @pop3, @pop3_port, @pop3_ssl, @smtp, @smtp_port, @smtp_ssl = email, password, pop3, pop3_port, pop3_ssl, smtp, smtp_port, smtp_ssl
      Mail.defaults do
        if(email.end_with? "@gmail.com") then email.insert(0, "recent:") end
        retriever_method :pop3, :address    => pop3,
                                :port       => pop3_port,
                                :user_name  => email,
                                :password   => password,
                                :enable_ssl => (pop3_ssl == 1 ? true : false)

        delivery_method :smtp, :address                => smtp,
                               :port                   => smtp_port,
                               :domain                 => email.split('@')[1],
                               :user_name              => email,
                               :password               => password,
                               :ssl                    => (smtp_ssl == 1 ? true : false),
                               :authentication         => 'plain',
                               :enable_start_ttls_auto => true
      end
    end

    def sync_mail
      new_mail = last_synced == nil ? Mail.all : Mail.all.select { |mail| mail.date > last_synced }
      new_mail.each do |mail|
        text, html = nil, mail.body.decoded
        if(mail.text_part != nil) then text = mail.text_part.decoded end
        if(mail.html_part != nil) then html = mail.html_part.decoded end
        puts "Downloading: \"#{mail.subject}\""
        @database.execute(
          "INSERT INTO emails VALUES(NULL, ?, ?, ?, ?, ?, ?, ?, 0)",
          mail.message_id,
          text,
          html,
          mail.from,
          mail.to,
          mail.subject,
          mail.date.to_s
        )
        mail.attachments.reject { |attachment| attachment.inline? }.each do |attachment|
          @database.execute(
            "INSERT INTO attachments VALUES(NULL, @id, @file_name, @attachment)",
            mail.message_id,
            attachment.filename,
            attachment.body.decoded
          )
        end
      end
    end

    def last_synced
      last_date = @database.execute("SELECT received FROM emails WHERE id = (SELECT MAX(id) FROM emails WHERE instr(@username, [to]) > 0)", @email).flatten[0]
      if last_date
        DateTime.parse(last_date)
      else
        nil
      end
    end

    def send_mail(recipient, subj, message, attachments = [])
      sender = email
      Mail.deliver do
        from sender
        to recipient
        subject subj
        body message
        attachments.each do |att|
          add_file att
        end
      end
    end

    def email
      (@email.start_with? "recent:") ? @email.split(":")[1] : @email
    end

    def unread
      @database.execute("SELECT * FROM emails WHERE read = 0 AND [to]=@email", @email)
    end
  end
end