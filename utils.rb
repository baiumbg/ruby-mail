require 'sqlite3'

module RubyMail
  class Utilities

    @@database = SQLite3::Database.new("data.db")

    def self.user_exists?(user_name)
      @@database.execute("SELECT * FROM sqlite_master WHERE name='users' AND type='table'").flatten.any? &&
      @@database.execute("SELECT * FROM users WHERE email = ?", user_name).flatten.any?
    end

    def self.get_mail_by_id(id)
      @@database.execute("SELECT * FROM emails WHERE id = ?", id).flatten
    end

    def self.get_mail_by_message_id(message_id)
      @@database.execute("SELECT * FROM emails WHERE message_id = ?", message_id).flatten
    end

    def self.get_attachment_names(message_id)
      @@database.execute("SELECT file_name FROM attachments WHERE message_id = ?", message_id).flatten
    end

    def self.mail_has_attachments(message_id)
      @@database.execute("SELECT COUNT(id) FROM attachments WHERE message_id = ?", message_id).flatten[0].to_i > 0
    end

    def self.clear_screen
      system "cls" or system "clear"
    end

    def self.del_user(user_name)
      @@database.execute("DELETE FROM users WHERE email = ?", user_name)
      @@database.execute("DELETE FROM attachments WHERE message_id IN (SELECT message_id FROM emails WHERE [to] = ?)", user_name)
      @@database.execute("DELETE FROM emails WHERE [to] = ?", user_name)
      @@database.execute("DELETE FROM user_config WHERE email = ?", user_name)
    end
    
    def self.del_mail(mail_id)
      @@database.execute("DELETE FROM emails WHERE id = ?", mail_id)
    end
  end
end