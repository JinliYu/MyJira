class UserMailer < ActionMailer::Base
  default :from => "MyJira Team <myjirateam@gmail.com>"
  
    def registration_confirmation(user)
      @user = user
      mail(:to => "#{user.name} <#{user.email}>", :subject => "Registration Confirmation")
   end

end
