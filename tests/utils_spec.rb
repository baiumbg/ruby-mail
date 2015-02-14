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
    @db.execute("DELETE FROM users")
    @db.execute("DELETE FROM emails")
    @db.execute("DELETE FROM attachments")
    @db.execute("DELETE FROM user_config")
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

  describe "::get_mail_by_id" do
    it "returns empty array if mail does not exist" do
      expect(RubyMail::Utilities.get_mail_by_id(1)).to have_exactly(0).items
    end

    it "returns correct mail" do
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(2, '<message-id2>', 'test body2', '<h1>test body2</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject2', '2015-02-11T16:28:08+02:00', 0)")
      expect(RubyMail::Utilities.get_mail_by_id(2)).to eq([2, '<message-id2>', 'test body2', '<h1>test body2</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject2', '2015-02-11T16:28:08+02:00', 0])
    end
  end
  describe "::get_mail_by_message_id" do
    it "returns empty array if mail does not exist" do
      expect(RubyMail::Utilities.get_mail_by_message_id('<message-id>')).to have_exactly(0).items
    end

    it "returns correct mail" do
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(2, '<message-id2>', 'test body2', '<h1>test body2</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject2', '2015-02-11T16:28:08+02:00', 0)")
      expect(RubyMail::Utilities.get_mail_by_message_id('<message-id2>')).to eq([2, '<message-id2>', 'test body2', '<h1>test body2</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject2', '2015-02-11T16:28:08+02:00', 0])
    end
  end
  describe "::get_attachment_names" do
    it "returns empty array if mail does not have attachments" do
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      expect(RubyMail::Utilities.get_attachment_names('<message-id>')).to have_exactly(0).items
    end

    it "returns correct attachment names" do
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO attachments VALUES(1, '<message-id>', 'test.txt', 'test file')")
      @db.execute("INSERT INTO attachments VALUES(2, '<message-id2>', 'test2.txt', 'test file2')")
      @db.execute("INSERT INTO attachments VALUES(3, '<message-id>', 'test3.txt', 'test file3')")
      expect(RubyMail::Utilities.get_attachment_names('<message-id>')).to include('test.txt', 'test3.txt')
    end
  end
  describe "::mail_has_attachments" do
    it "returns false if mail does not have attachments" do
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      expect(RubyMail::Utilities.mail_has_attachments('<message-id>')).to be false
    end
    
    it "returns true if mail has attachments" do
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO attachments VALUES(1, '<message-id>', 'test.txt', 'test file')")
      expect(RubyMail::Utilities.mail_has_attachments('<message-id>')).to be true
    end
  end
  describe "::del_user" do
    it "correctly removes all data about user" do
      @db.execute("INSERT INTO users VALUES(1, 'ruby.mail.test@abv.bg', 'test_pass1', 'pop3.abv.bg', 995, 'smtp.abv.bg', 465, 1, 1)")
      @db.execute("INSERT INTO users VALUES(2, 'baiumbg@gmail.com', 'top_secret', 'pop.gmail.com', 995, 'smtp.gmail.com', 587, 1, 0)")
      @db.execute("INSERT INTO user_config VALUES(1, 'ruby.mail.test@abv.bg', 120, 10)")
      @db.execute("INSERT INTO user_config VALUES(2, 'baiumbg@gmail.com', 120, 10)")
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(2, '<message-id2>', 'test body2', '<h1>test body2</h1>', 'ruby.mail.test@abv.bg', 'baiumbg@gmail.com', 'test subject2', '2015-02-11T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(3, '<message-id3>', 'test body3', '<h1>test body3</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject3', '2015-02-12T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO attachments VALUES(1, '<message-id>', 'test.txt', 'test file')")
      @db.execute("INSERT INTO attachments VALUES(2, '<message-id2>', 'test2.txt', 'test file2')")
      RubyMail::Utilities.del_user("ruby.mail.test@abv.bg")
      expect(@db.execute("SELECT * FROM users")).to eq([[2, 'baiumbg@gmail.com', 'top_secret', 'pop.gmail.com', 995, 'smtp.gmail.com', 587, 1, 0]])
      expect(@db.execute("SELECT * FROM user_config")).to eq([[2, 'baiumbg@gmail.com', 120, 10]])
      expect(@db.execute("SELECT * FROM emails")).to eq([[2, '<message-id2>', 'test body2', '<h1>test body2</h1>', 'ruby.mail.test@abv.bg', 'baiumbg@gmail.com', 'test subject2', '2015-02-11T16:28:08+02:00', 0]])
      expect(@db.execute("SELECT * FROM attachments")).to eq([[2, '<message-id2>', 'test2.txt', 'test file2']])
    end
  end
  describe "::del_mail" do
    it "correctly removes mail" do
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(2, '<message-id2>', 'test body2', '<h1>test body2</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject2', '2015-02-11T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(3, '<message-id3>', 'test body3', '<h1>test body3</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject3', '2015-02-12T16:28:08+02:00', 0)")
      RubyMail::Utilities.del_mail(2)
      expect(@db.execute("SELECT * FROM emails")).to include(
        [1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0],
        [3, '<message-id3>', 'test body3', '<h1>test body3</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject3', '2015-02-12T16:28:08+02:00', 0]
      )
    end
  end
end