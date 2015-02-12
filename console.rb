require './client.rb'
require './utils.rb'
require 'io/console'

module RubyMail
  class ConsoleInterface
    def initialize
      @client = nil
      @syncer = nil
      start_preshell
    end

    def start_preshell
      cmd = ""

      until cmd == "login" || cmd == "quit"
        print "RubyMail$ "
        cmd = gets.chomp
        process_cmd cmd, true
      end

      start_shell if cmd == "login"
    end

    def start_shell
      Utilities.clear_screen
      cmd = ""
      until cmd == "quit" || cmd == "logout"
        print "#{@client.settings[:email]}$ "
        cmd = gets.chomp
        process_cmd cmd
      end
    end

    def process_cmd(cmd, preshell = false)
      args = cmd.split ' '
      case args[0]
      when "login"
        if preshell then login
        else puts "You are already logged in. Type \"logout\" if you want to switch users." end
      when "home"
        if preshell then "You need to be logged in to visit the home screen."
        elsif args.length > 1 then puts "home doesn't take any arguments."
        else home end
      when "inbox"
        if preshell then puts "You need to be logged in to view your inbox."
        elsif args.length > 2
          puts "Too many arguments."
        else
          Utilities.clear_screen
          if args[1] then show_inbox(args[1].to_i)
          else show_inbox end
        end
      when "read"
        if preshell then puts "You need to be logged in to read mail."
        elsif args.length > 2 
          puts "Too many arguments."
        elsif args.length < 2
          puts "Missing arguments."
        else
          Utilities.clear_screen
          read_mail(args[1].to_i)
        end
      when "mark"
        if preshell then puts "You need to be logged in to mark any messages."
        elsif args.length > 3 then puts "Too many arguments."
        elsif args.length < 3 then puts "Missing arguments."
        elsif(args[1] == "all" && (args[2] == "read" || args[2] == "unread")) then mark_as(args[2])
        else help("mark") end
      when "compose"
        if preshell then puts "You need to be logged in to compose an email."
        elsif args.length > 1 then puts "compose doesn't take any arguments."
        else compose end
      when "sync"
        if preshell then puts "You need to be logged in to sync your inbox."
        elsif(args.length > 1) then puts "sync doesn't take any arguments."
        else sync end
      when "config"
        if preshell then puts "You need to be logged in to configure client settings."
        elsif args.length == 1 then config(true)
        elsif args.length < 3 then puts "You need to specify a valid number to set that setting to."
        elsif args.length > 3 then puts "Too many arguments."
        else config(false, args[1], args[2].to_i) end
      when "logout"
        if preshell then puts "You need to be logged in to log out."
        else logout end
      when "quit"
        if @syncer then @syncer.kill end
      else puts "Unknown command." end
    end

    def login
      print "\nUsername: "
      user_name = gets.chomp

      if(Utilities.user_exists? user_name) then @client = Client.new(user_name)
      else
        print "Password: "
        password = STDIN.noecho(&:gets).chomp

        print "\nPOP3 Server: "
        pop3_server = gets.chomp

        print "POP3 Server Port: "
        pop3_port = gets.chomp.to_i

        print "Enable SSL? (0 or 1): "
        pop3_ssl = gets.chomp.to_i

        print "SMTP Server: "
        smtp_server = gets.chomp

        print "SMTP Server Port: "
        smtp_port = gets.chomp.to_i

        print "Enable SSL? (0 or 1): "
        smtp_ssl = gets.chomp.to_i

        @client = Client.new(user_name, password, pop3_server, pop3_port, pop3_ssl, smtp_server, smtp_port, smtp_ssl)
      end

      start_sync
      home
    end

    def start_sync
      @syncer = Thread.new do
        loop do
          @client.sync_mail
          sleep(@client.settings[:sync_delay])
        end
      end
    end

    def home
      Utilities.clear_screen
      puts "Welcome!\n\nYou have #{@client.unread.count} unread messages.\n\n"
    end

    def show_inbox(page = 1)
      total_pages = (@client.inbox_total / @client.settings[:mails_per_page].to_f).ceil
      @client.get_inbox(page).each do |mail|
        print "~" if mail[4] == 0
        puts "#{mail[0]} | #{mail[1]} | #{mail[2]} | #{mail[3]}"
      end
      puts "\nPage: #{page}/#{total_pages}\n"
      puts "Type \"inbox \#\" to show that page of your inbox."
    end

    def read_mail(id)
      mail = @client.get_mail(id)
      if mail == nil then puts "No mail with id #{id}."
      else
        puts "From: #{mail[:from]}"
        puts "To: #{mail[:to]}"
        puts "Subject: #{mail[:subject]}"
        puts "Received at: #{mail[:received]}"
        print "\n\n"
        if mail[:text] == nil then puts mail[:html]
        else puts mail[:text] end
      end
    end

    def mark_as(value)
      if value == "read" then @client.mark_as(:all, true)
      else @client.mark_as(:all, false) end
    end

    def compose
      print "To: "
      mail_to = gets.chomp
      print "Subject: "
      mail_subject = gets.chomp
      puts "Content:\n"
      mail_content = ""
      line = ""
      until line.chomp == "end"
        line = gets
        mail_content.concat(line) unless line.chomp == "end"
      end
      puts "Sending mail ..."
      @client.send_mail(mail_to, mail_subject, mail_content)
      puts "Successfully sent!"
    end

    def sync
      @client.sync_mail
    end

    def config(print_current_config, setting=nil, new_value=nil)
      if print_current_config
        puts "Current settings:\n\n"
        puts "password: #{"*" * @client.settings[:password].length}"
        puts "pop3_server: #{@client.settings[:pop3_server]}"
        puts "pop3_port: #{@client.settings[:pop3_port]}"
        puts "pop3_ssl: #{@client.settings[:pop3_ssl]}"
        puts "smtp_server: #{@client.settings[:smtp_server]}"
        puts "smtp_port: #{@client.settings[:smtp_port]}"
        puts "smtp_ssl: #{@client.settings[:smtp_ssl]}"
        puts "sync_delay: #{@client.settings[:sync_delay]}"
        puts "mails_per_page: #{@client.settings[:mails_per_page]}\n\n"
      else
        case setting
        when "sync_delay"
          if new_value < 60 then puts "Minimum value for that setting is 60."
          else @client.configure(:sync_delay, new_value) end
        when "mails_per_page"
          if new_value < 2 then puts "Minimum value for that setting is 2."
          else @client.configure(:inbox_mails_per_page, new_value) end
        end
      end
    end

    def logout
      @client = nil
      @syncer.kill
      @syncer = nil
      start_preshell
    end
  end
end

test = RubyMail::ConsoleInterface.new