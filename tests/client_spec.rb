require_relative '../client'
require 'rspec/collection_matchers'

describe RubyMail::Client do
  before :all do
    @db = SQLite3::Database.new("data.db")
  end

  before :each do
    @db.execute("DROP TABLE IF EXISTS users")
    @db.execute("DROP TABLE IF EXISTS user_config")
    @db.execute("DROP TABLE IF EXISTS emails")
    @db.execute("DROP TABLE IF EXISTS attachments")
    @test_user = RubyMail::Client.new('ruby.mail.test@abv.bg', 'test_pass1', 'pop3.abv.bg', 995, 1, 'smtp.abv.bg', 465, 1)
  end

  after :all do
    File.delete("attachments/test.txt")
  end

  describe "\#new" do
    it "initializes client and inserts new user into db" do
      expect(@test_user).to be_instance_of(RubyMail::Client)
      expect(@db.execute("SELECT * FROM users WHERE email = 'ruby.mail.test@abv.bg'")).to have_exactly(1).items
    end

    it "correctly initializes client from existing user" do
      @test_user = RubyMail::Client.new('ruby.mail.test@abv.bg')
      expect(@test_user).to be_instance_of(RubyMail::Client)
      expect(@test_user.settings).to eq({
        email:          "ruby.mail.test@abv.bg",
        password:       "test_pass1",
        pop3_server:    "pop3.abv.bg",
        pop3_port:      995,
        pop3_ssl:       1,
        smtp_server:    "smtp.abv.bg",
        smtp_port:      465,
        smtp_ssl:       1,
        sync_delay:     120,
        mails_per_page: 10
      })
      expect(@db.execute("SELECT * FROM users WHERE email = 'ruby.mail.test@abv.bg'")).to have_exactly(1).items
    end

    it "throws exception when initializing from a non-existing user" do
      expect {RubyMail::Client.new('random_email@test.test')}.to raise_error
    end
  end

  describe "\#get_mail" do
    it "retrieves correct mail info from db" do
      test = RubyMail::Client.new('ruby.mail.test@abv.bg', 'v9504132', 'pop3.abv.bg', 995, 1, 'smtp.abv.bg', 465, 1)
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO attachments VALUES(1, '<message-id>', 'test.txt', 'test file')")
      expect(test.get_mail(1)).to eq({
        id: 1,
        from: 'baiumbg@gmail.com',
        to: 'ruby.mail.test@abv.bg',
        subject: 'test subject',
        received: '2015-02-10T16:28:08+02:00',
        text: 'test body',
        html: '<h1>test body</h1>',
        message_id: '<message-id>',
        attachments: ['test.txt'],
        read: 0
      })
    end

    it "returns nil if mail not found while fetching" do
      test = RubyMail::Client.new('ruby.mail.test@abv.bg', 'v9504132', 'pop3.abv.bg', 995, 1, 'smtp.abv.bg', 465, 1)
      expect(test.get_mail(1)).to eq(nil)
    end
  end

  describe "\#extract_attachments" do
    it "extracts attachments from mail" do
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO attachments VALUES(1, '<message-id>', 'test.txt', 'test file')")
      @test_user.extract_attachments(1)
      expect(File.file? "attachments/test.txt").to be true
      expect(IO.read("attachments/test.txt")).to eq("test file")
    end
  end

  describe "\#inbox_total" do
    it "returns zero if inbox is empty" do
      expect(@test_user.inbox_total).to eq(0)
    end

    it "returns correct mail count" do
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      expect(@test_user.inbox_total).to eq(1)
      @db.execute("INSERT INTO emails VALUES(2, '<message-id2>', 'test body2', '<h1>test body2</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject2', '2015-02-11T16:28:08+02:00', 0)")
      expect(@test_user.inbox_total).to eq(2)
    end
  end

  describe "\#get_inbox" do
    it "returns empty array if no mails in inbox" do
      expect(@test_user.get_inbox(1)).to have_exactly(0).items
    end

    it "returns all mails if total count under mails_per_page" do
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(2, '<message-id2>', 'test body2', '<h1>test body2</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject2', '2015-02-11T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(3, '<message-id3>', 'test body3', '<h1>test body3</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject3', '2015-02-12T16:28:08+02:00', 0)")
      expect(@test_user.get_inbox(1)).to have_exactly(3).items
    end

    it "returns correct mails if total count above mails_per_page" do
      @test_user.configure(:mails_per_page, 2)
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(2, '<message-id2>', 'test body2', '<h1>test body2</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject2', '2015-02-11T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(3, '<message-id3>', 'test body3', '<h1>test body3</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject3', '2015-02-12T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(4, '<message-id3>', 'test body4', '<h1>test body4</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject4', '2015-02-13T16:28:08+02:00', 0)")
      expect(@test_user.get_inbox(2)).to eq([
        {
          id: 2,
          from: 'baiumbg@gmail.com',
          to: 'ruby.mail.test@abv.bg',
          subject: 'test subject2',
          received: '2015-02-11T16:28:08+02:00',
          text: 'test body2',
          html: '<h1>test body2</h1>',
          message_id: '<message-id2>',
          attachments: [],
          read: 0
        },
        {
          id: 1,
          from: 'baiumbg@gmail.com',
          to: 'ruby.mail.test@abv.bg',
          subject: 'test subject',
          received: '2015-02-10T16:28:08+02:00',
          text: 'test body',
          html: '<h1>test body</h1>',
          message_id: '<message-id>',
          attachments: [],
          read: 0
        }
      ])
    end
  end

  describe "\#configure" do
    it "correctly sets :password" do
      @test_user.configure(:password, 'test_pass2')
      expect(@test_user.settings[:password]).to eq('test_pass2')
      expect(@db.execute("SELECT password FROM users WHERE email='ruby.mail.test@abv.bg'").flatten[0]).to eq('test_pass2')
    end

    it "correctly sets :pop3_server" do
      @test_user.configure(:pop3_server, 'pop.gmail.com')
      expect(@test_user.settings[:pop3_server]).to eq('pop.gmail.com')
      expect(@db.execute("SELECT pop3_server FROM users WHERE email='ruby.mail.test@abv.bg'").flatten[0]).to eq('pop.gmail.com')
    end

    it "correctly sets :pop3_port" do
      @test_user.configure(:pop3_port, 666)
      expect(@test_user.settings[:pop3_port]).to eq(666)
      expect(@db.execute("SELECT pop3_port FROM users WHERE email='ruby.mail.test@abv.bg'").flatten[0]).to eq(666)
    end

    it "correctly sets :pop3_ssl" do
      @test_user.configure(:pop3_ssl, 0)
      expect(@test_user.settings[:pop3_ssl]).to eq(0)
      expect(@db.execute("SELECT pop3_ssl FROM users WHERE email='ruby.mail.test@abv.bg'").flatten[0]).to eq(0)
    end

    it "correctly sets :smtp_server" do
      @test_user.configure(:smtp_server, 'smtp.gmail.com')
      expect(@test_user.settings[:smtp_server]).to eq('smtp.gmail.com')
      expect(@db.execute("SELECT smtp_server FROM users WHERE email='ruby.mail.test@abv.bg'").flatten[0]).to eq('smtp.gmail.com')
    end

    it "correctly sets :smtp_port" do
      @test_user.configure(:smtp_port, 587)
      expect(@test_user.settings[:smtp_port]).to eq(587)
      expect(@db.execute("SELECT smtp_port FROM users WHERE email='ruby.mail.test@abv.bg'").flatten[0]).to eq(587)
    end

    it "correctly sets :smtp_ssl" do
      @test_user.configure(:smtp_ssl, 0)
      expect(@test_user.settings[:smtp_ssl]).to eq(0)
      expect(@db.execute("SELECT smtp_ssl FROM users WHERE email='ruby.mail.test@abv.bg'").flatten[0]).to eq(0)
    end

    it "correctly sets :sync_delay" do
      @test_user.configure(:sync_delay, 180)
      expect(@test_user.settings[:sync_delay]).to eq(180)
      expect(@db.execute("SELECT sync_delay FROM user_config WHERE email='ruby.mail.test@abv.bg'").flatten[0]).to eq(180)
    end

    it "correctly sets :mails_per_page" do
      @test_user.configure(:mails_per_page, 5)
      expect(@test_user.settings[:mails_per_page]).to eq(5)
      expect(@db.execute("SELECT mails_per_page FROM user_config WHERE email='ruby.mail.test@abv.bg'").flatten[0]).to eq(5)
    end
  end

  describe "\#mark_as" do
    before :each do
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(2, '<message-id2>', 'test body2', '<h1>test body2</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject2', '2015-02-11T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(3, '<message-id3>', 'test body3', '<h1>test body3</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject3', '2015-02-12T16:28:08+02:00', 0)")
    end
    it "marks all as read/unread" do
      @test_user.mark_as(:all, true)
      expect(@db.execute("SELECT read FROM emails WHERE [to] = 'ruby.mail.test@abv.bg'").flatten).to eq([1, 1, 1])
    end

    it "marks specific mails as read/unread" do
      @test_user.mark_as(['<message-id>', '<message-id3>'], true)
      expect(@db.execute("SELECT read FROM emails WHERE [to] = 'ruby.mail.test@abv.bg'").flatten).to eq([1, 0, 1])
    end
  end

  describe "\#unread" do
    it "returns empty array if no mails in inbox" do
      expect(@test_user.unread).to eq([])
    end

    it "returns correct mails" do
      @db.execute("INSERT INTO emails VALUES(1, '<message-id>', 'test body', '<h1>test body</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject', '2015-02-10T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(2, '<message-id2>', 'test body2', '<h1>test body2</h1>', 'baiumbg@gmail.com', 'ruby.mail.test@abv.bg', 'test subject2', '2015-02-11T16:28:08+02:00', 0)")
      @db.execute("INSERT INTO emails VALUES(3, '<message-id3>', 'test body', '<h1>test body</h1>', 'ruby.mail.test@abv.bg', 'baiumbg@gmail.com', 'test subject', '2015-02-14T16:28:08+02:00', 0)")
      expect(@test_user.unread.count).to eq(2)
      expect(@test_user.unread).to include(
        {
          id: 1,
          from: 'baiumbg@gmail.com',
          to: 'ruby.mail.test@abv.bg',
          subject: 'test subject',
          received: '2015-02-10T16:28:08+02:00',
          text: 'test body',
          html: '<h1>test body</h1>',
          message_id: '<message-id>',
          attachments: [],
          read: 0
        },
        {
          id: 2,
          from: 'baiumbg@gmail.com',
          to: 'ruby.mail.test@abv.bg',
          subject: 'test subject2',
          received: '2015-02-11T16:28:08+02:00',
          text: 'test body2',
          html: '<h1>test body2</h1>',
          message_id: '<message-id2>',
          attachments: [],
          read: 0
        }
      )
    end
  end
end