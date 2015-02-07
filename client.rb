require 'sqlite3'
require 'mail'

module RubyMail
  class Client
    def initialize(email, password, pop3, pop3_port, ssl, smtp, smtp_port)
      init_db
      init_mail(email, password, pop3, pop3_port, ssl, smtp, smtp_port)
      sync_mail email
      #puts "#{unread.count} unread emails"
    end

    def init_db
      @database = SQLite3::Database.new("data.db")
      @database.execute "CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT, password TEXT, pop3 TEXT, pop3_port INTEGER, smtp TEXT, smtp_port INTEGER, ssl INTEGER)"
      @database.execute "CREATE TABLE IF NOT EXISTS emails(id INTEGER PRIMARY KEY AUTOINCREMENT, message_id TEXT, text TEXT, html TEXT, [from] TEXT, [to] TEXT, subject TEXT, received TEXT, read INTEGER)"
      @database.execute "CREATE TABLE IF NOT EXISTS attachments(id INTEGER PRIMARY KEY AUTOINCREMENT, message_id TEXT, file_name TEXT, attachment BLOB)"
    end

    def init_mail(email, password, pop3, pop3_port, ssl, smtp, smtp_port)
      Mail.defaults do
        if(email.end_with? "@gmail.com") then username.insert(0, "recent:") end
        retriever_method :pop3, :address    => pop3,
                                :port       => pop3_port,
                                :user_name  => email,
                                :password   => password,
                                :enable_ssl => ssl

        delivery_method :smtp, :address                => smtp,
                               :port                   => smtp_port,
                               :domain                 => smtp,
                               :user_name              => email,
                               :password               => password,
                               :authentication         => 'plain',
                               :enable_start_ttls_auto => true

        @unread = []
      end
    end

    def sync_mail(email)
      last_synced = @database.execute("SELECT message_id FROM emails WHERE id = (SELECT MAX(id) FROM emails WHERE [to] = @username)", email).flatten[0]
      new_mail = []
      if(last_synced == nil)
        new_mail = Mail.all
      else
        Mail.all.reverse.each do |mail|
          if(mail.message_id != last_synced) then new_mail.push(mail) end
          break if mail.message_id == last_synced
        end
        new_mail.reverse!
      end
      new_mail.each do |mail|
        @database.execute(
          "INSERT INTO emails VALUES(NULL, @id, @text, @html, @from, @to, @subject, @received, 0)",
          mail.message_id,
          mail.text_part.decoded,
          mail.html_part.decoded,
          mail.from,
          mail.to,
          mail.subject,
          mail.date.to_s
        )
        mail.attachments.each do |attachment|
          @database.execute(
            "INSERT INTO attachments VALUES(NULL, @id, @file_name, @attachment)",
            mail.message_id,
            attachment.filename,
            attachment.body.decoded
          )
        end
      end
    end
    
    def unread
      @database.execute("SELECT * FROM emails WHERE read = 0")
    end
  end
end

test = RubyMail::Client.new("", "", "pop3.abv.bg", 995, true, "smtp.abv.bg", 465)