require_relative '../utils'

describe RubyMail::Utilities do
  before :all do
    @db = SQLite3::Database.new("data.db")
  end
  before :each do
    @db.execute("CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT, password TEXT, pop3_server TEXT, pop3_port INTEGER, smtp_server TEXT, smtp_port INTEGER, pop3_ssl INTEGER, smtp_ssl INTEGER)")
    @db.execute("CREATE TABLE IF NOT EXISTS emails(id INTEGER PRIMARY KEY AUTOINCREMENT, message_id TEXT, text TEXT, html TEXT, [from] TEXT, [to] TEXT, subject TEXT, received TEXT, read INTEGER)")
    @db.execute("CREATE TABLE IF NOT EXISTS attachments(id INTEGER PRIMARY KEY AUTOINCREMENT, message_id TEXT, file_name TEXT, attachment BLOB)")
    @db.execute("CREATE TABLE IF NOT EXISTS user_config(id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT, sync_delay INTEGER, mails_per_page INTEGER)")
  end

  describe "::user_exists?" do
    it "returns false if table doesn't exists" do
      @db.execute("DROP TABLE users")
      expect(RubyMail::Utilities.user_exists?("ruby.mail.test@abv.bg")).to be false
    end

    it "returns false if user doesn't exist" do
      expect(RubyMail::Utilities.user_exists?("ruby.mail.test@abv.bg")).to be false
    end

    it "returns true if user exists" do
      @db.execute("INSERT INTO users VALUES(NULL, 'ruby.mail.test@abv.bg', 'test_pass1', 'pop3.abv.bg', 995, 'smtp.abv.bg', 465, 1, 1)")
      expect(RubyMail::Utilities.user_exists?("ruby.mail.test@abv.bg")).to be true
    end
  end
end