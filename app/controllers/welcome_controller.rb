class WelcomeController < ApplicationController
  helper :tickets

  def index
#    if current_user.is_a?(Admin) || current_user.is_a?(Technician)
      @history = TicketHistoryEntry.paginate(
        :page     => params[:page],
        :per_page => params[:per_page] || 30,
        :order    => "created_at DESC"
      )
#    end
  end
end
