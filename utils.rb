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
    def self.clear_screen
      system "cls" or system "clear"
    end
  end
end