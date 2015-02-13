require 'sqlite3'
require 'mail'
require_relative './utils'

module RubyMail
  class Client
    attr_writer :email
    attr_reader :settings

    def initialize(user_name, password = nil, pop3_server = nil, pop3_port = nil, pop3_ssl = nil, smtp_server = nil, smtp_port = nil, smtp_ssl=nil)
      init_db
      if Utilities.user_exists? user_name
        user_info = @database.execute("SELECT password, pop3_server, pop3_port, smtp_server, smtp_port, pop3_ssl, smtp_ssl FROM users WHERE email = ?", user_name).flatten
        password, pop3_server, pop3_port, smtp_server, smtp_port, pop3_ssl, smtp_ssl = user_info
      elsif(password == nil || pop3_server == nil || pop3_port == nil || pop3_ssl == nil || smtp_server == nil || smtp_port == nil || smtp_ssl == nil)
        throw "Wrong number of arguments or user does not exist"
      else
        @database.execute("INSERT INTO users VALUES(NULL, ?, ?, ?, ?, ?, ?, ?, ?)", user_name, password, pop3_server, pop3_port, smtp_server, smtp_port, pop3_ssl, smtp_ssl)
        @database.execute("INSERT INTO user_config VALUES(NULL, ?, 120, 10)", user_name)
      end
      init_mail(user_name, password, pop3_server, pop3_port, pop3_ssl, smtp_server, smtp_port, smtp_ssl)
      init_settings
      Dir.mkdir("attachments") unless Dir.exist?("attachments")
    end

    def init_db
      @database = SQLite3::Database.new("data.db")
      @database.execute("CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT, password TEXT, pop3_server TEXT, pop3_port INTEGER, smtp_server TEXT, smtp_port INTEGER, pop3_ssl INTEGER, smtp_ssl INTEGER)")
      @database.execute("CREATE TABLE IF NOT EXISTS emails(id INTEGER PRIMARY KEY AUTOINCREMENT, message_id TEXT, text TEXT, html TEXT, [from] TEXT, [to] TEXT, subject TEXT, received TEXT, read INTEGER)")
      @database.execute("CREATE TABLE IF NOT EXISTS attachments(id INTEGER PRIMARY KEY AUTOINCREMENT, message_id TEXT, file_name TEXT, attachment BLOB)")
      @database.execute("CREATE TABLE IF NOT EXISTS user_config(id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT, sync_delay INTEGER, mails_per_page INTEGER)")
    end

    def init_mail(user_name, user_pass, pop3_server, pop3_port, pop3_ssl, smtp_server, smtp_port, smtp_ssl)
      @settings = {
        email:       user_name.dup,
        password:    user_pass,
        pop3_server: pop3_server,
        pop3_port:   pop3_port,
        pop3_ssl:    pop3_ssl,
        smtp_server: smtp_server,
        smtp_port:   smtp_port,
        smtp_ssl:    smtp_ssl
      }

      user_name.insert(0, "recent:") if user_name.end_with? "@gmail.com"

      Mail.defaults do
        retriever_method :pop3, address:    pop3_server,
                                port:       pop3_port,
                                user_name:  user_name,
                                password:   user_pass,
                                enable_ssl: (pop3_ssl == 1 ? true : false)

        delivery_method :smtp, address:                smtp_server,
                               port:                   smtp_port,
                               domain:                 user_name.split('@')[1],
                               user_name:              user_name,
                               password:               user_pass,
                               ssl:                    (smtp_ssl == 1 ? true : false),
                               authentication:         'plain',
                               enable_start_ttls_auto: true
      end
    end

    def get_mail(id)
      mail = Utilities.get_mail_by_id(id)
      if mail == [] then nil
      else
        {
          id: mail[0],
          from: mail[4],
          to: mail[5],
          subject: mail[6],
          received: mail[7],
          text: mail[2],
          html: mail[3],
          message_id: mail[1],
          attachments: Utilities.get_attachment_names(mail[1]),
          read: mail[8]
        }
      end
    end

    def extract_attachments(mail_id)
      mail = get_mail(mail_id)
      @database.execute("SELECT * FROM attachments WHERE message_id = ?", mail[:message_id]).each do |attachment|
        File.write("attachments/#{attachment[2]}", attachment[3])
      end
    end

    def init_settings
      @settings[:sync_delay], @settings[:mails_per_page] = @database.execute("SELECT sync_delay, mails_per_page FROM user_config WHERE email = ?", @settings[:email]).flatten
    end

    def sync_mail
      new_mail = last_synced == nil ? Mail.all : Mail.all.select { |mail| mail.date > last_synced }
      new_mail.each do |mail|
        text, html = nil, mail.body.decoded
        text = mail.text_part.decoded unless mail.text_part == nil
        html = mail.html_part.decoded unless mail.html_part == nil
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
      last_date = @database.execute("SELECT received FROM emails WHERE id = (SELECT MAX(id) FROM emails WHERE instr(?, [to]) > 0)", @settings[:email]).flatten[0]
      if last_date
        DateTime.parse(last_date)
      else
        nil
      end
    end

    def send_mail(recipient, subj, message, attachments = [])
      sender = @settings[:email]
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

    def inbox_total
      @database.execute("SELECT COUNT(id) FROM emails WHERE [to] = ?", @settings[:email]).flatten[0]
    end

    def get_inbox(page)
      mails = []
      @database.execute(
        "SELECT id FROM emails WHERE [to] = ? ORDER BY id DESC LIMIT ?, ?",
        @settings[:email],
        @settings[:mails_per_page] * (page - 1),
        @settings[:mails_per_page]
      ).flatten.each do |mail_id|
        mails << get_mail(mail_id)
      end
      mails
    end

    def configure(setting, value)
      @settings[setting] = value
      case setting
      when :password then @database.execute("UPDATE users SET password = ? WHERE email = ?", value, @settings[:email])
      when :pop3_server then @database.execute("UPDATE users SET pop3_server = ? WHERE email = ?", value, @settings[:email])
      when :pop3_port then @database.execute("UPDATE users SET pop3_port = ? WHERE email = ?", value, @settings[:email])
      when :pop3_ssl then @database.execute("UPDATE users SET pop3_ssl = ? WHERE email = ?", value, @settings[:email])
      when :smtp_server then @database.execute("UPDATE users SET smtp_server = ? WHERE email = ?", value, @settings[:email])
      when :smtp_port then @database.execute("UPDATE users SET smtp_port = ? WHERE email = ?", value, @settings[:email])
      when :smtp_ssl then @database.execute("UPDATE users SET smtp_ssl = ? WHERE email = ?", value, @settings[:email])
      when :mails_per_page then @database.execute("UPDATE user_config SET mails_per_page = ? WHERE email = ?", value, @settings[:email])
      when :sync_delay then @database.execute("UPDATE user_config SET sync_delay = ? WHERE email = ?", value, @settings[:email])
      end
    end

    def mark_as(mails, read)
      if mails == :all then @database.execute("UPDATE emails SET read = ? WHERE [to] = ?", (read == true ? 1 : 0), @settings[:email])
      else
        mails.each do |mail|
          @database.execute("UPDATE emails SET read = ? WHERE message_id = ? AND [to] = ?", (read == true ? 1 : 0), mail, @settings[:email])
        end
      end
    end

    def unread
      unread_mails = []
      @database.execute("SELECT id FROM emails WHERE read = 0 AND [to] = ?", @settings[:email]).flatten.each do |id|
        unread_mails << get_mail(id)
      end
      unread_mails
    end
  end
end