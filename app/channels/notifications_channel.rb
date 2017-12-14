class TeamChannel < ApplicationCable::Channel
  def subscribed
    stream_from "#{current_user.id}_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
