require 'spec_helper'

describe Notice do
  
  context 'validations' do
    it 'requires a backtrace' do
      notice = Factory.build(:notice, :backtrace => nil)
      notice.should_not be_valid
      notice.errors[:backtrace].should include("can't be blank")
    end
    
    it 'requires the server_environment' do
      notice = Factory.build(:notice, :server_environment => nil)
      notice.should_not be_valid
      notice.errors[:server_environment].should include("can't be blank")
    end
    
    it 'requires the notifier' do
      notice = Factory.build(:notice, :notifier => nil)
      notice.should_not be_valid
      notice.errors[:notifier].should include("can't be blank")
    end
  end
  
  context '#from_xml' do
    before do
      @xml = Rails.root.join('spec','fixtures','hoptoad_test_notice.xml').read
      @app = Factory(:app, :api_key => 'APIKEY')
      Digest::MD5.stub(:hexdigest).and_return('fingerprintdigest')
    end
    
    it 'finds the correct app' do
      @notice = Notice.from_xml(@xml)
      @notice.err.app.should == @app
    end
    
    it 'finds the correct err for the notice' do
      Err.should_receive(:for).with({
        :app      => @app,
        :klass        => 'HoptoadTestingException',
        :component    => 'application',
        :action       => 'verify',
        :environment  => 'development',
        :fingerprint  => 'fingerprintdigest'
      }).and_return(err = Factory(:err))
      err.notices.stub(:create!)
      @notice = Notice.from_xml(@xml)
    end
    
    it 'marks the err as unresolve if it was previously resolved' do
      Err.should_receive(:for).with({
        :app      => @app,
        :klass        => 'HoptoadTestingException',
        :component    => 'application',
        :action       => 'verify',
        :environment  => 'development',
        :fingerprint  => 'fingerprintdigest'
      }).and_return(err = Factory(:err, :resolved => true))
      err.should be_resolved
      @notice = Notice.from_xml(@xml)
      @notice.err.should == err
      @notice.err.should_not be_resolved
    end
    
    it 'should create a new notice' do
      @notice = Notice.from_xml(@xml)
      @notice.should be_persisted
    end
    
    it 'assigns an err to the notice' do
      @notice = Notice.from_xml(@xml)
      @notice.err.should be_a(Err)
    end
    
    it 'captures the err message' do
      @notice = Notice.from_xml(@xml)
      @notice.message.should == 'HoptoadTestingException: Testing hoptoad via "rake hoptoad:test". If you can see this, it works.'
    end
    
    it 'captures the backtrace' do
      @notice = Notice.from_xml(@xml)
      @notice.backtrace.size.should == 73
      @notice.backtrace.last['file'].should == '[GEM_ROOT]/bin/rake'
    end
    
    it 'captures the server_environment' do
      @notice = Notice.from_xml(@xml)
      @notice.server_environment['environment-name'].should == 'development'
    end
    
    it 'captures the request' do
      @notice = Notice.from_xml(@xml)
      @notice.request['url'].should == 'http://example.org/verify'
      @notice.request['params']['controller'].should == 'application'
    end
    
    it 'captures the notifier' do
      @notice = Notice.from_xml(@xml)
      @notice.notifier['name'].should == 'Hoptoad Notifier'
    end
  end
  
  describe "email notifications" do
    before do
      @app = Factory(:app_with_watcher)
      @err = Factory(:err, :app => @app)
    end
    
    Errbit::Config.email_at_notices.each do |threshold|
      it "sends an email notification after #{threshold} notice(s)" do
        @err.notices.stub(:count).and_return(threshold)
        Mailer.should_receive(:err_notification).
          and_return(mock('email', :deliver => true))
        Factory(:notice, :err => @err)
      end
    end
  end
  
end