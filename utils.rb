require 'sqlite3'

module RubyMail
  class Utilities
    @@database = SQLite3::Database.new("data.db")
    def self.user_exists?(user_name)
      !@@database.execute("SELECT * FROM users WHERE email = @user_name", user_name).flatten.empty?
    end
  end
end