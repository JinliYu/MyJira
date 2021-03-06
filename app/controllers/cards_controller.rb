class CardsController < ApplicationController
  before_action :set_card, only: [:show, :edit, :update, :destroy]

  # GET /cards
  # GET /cards.json
  def index
    if logged_in?
      @cards = Card.all
    else
      @cards = []
    end
    respond_to do |format|
      format.html
      format.csv { send_data @cards.to_csv }
    end
  end

  # GET /cards/1
  # GET /cards/1.json
  def show
    if current_user != nil
      notes = current_user.notifications.where(card_id: @card.id)
      if (notes != nil)
        notes.each do |note|
          note.update(read: true)
        end
      end
    end
  end

  def show_modal
      @card = Card.find(params["card_id"])
      if current_user != nil
        notes = current_user.notifications.where(card_id: @card.id)
        if (notes != nil)
          notes.each do |note|
            note.update(read: true)
          end
        end

      end

    done_list_id = @card.list.board.lists.where(name: "done").first.id
    card_attributes = @card.as_json
    card_attributes['tags'] = @card.tags.as_json
    card_attributes['members'] = @card.users.as_json
    card_attributes['precards_done'] = @card.precards.where(list_id: done_list_id).as_json
    card_attributes['precards_undone'] = @card.precards.where.not(list_id:done_list_id).as_json
    card_attributes['comments'] = @card.comments.as_json
    card_attributes['comments'].each do |comment|
      comment['from_user_name'] = User.find(comment['from_user_id'].to_i).name
      if comment['to_user_id'] != nil
        comment['to_user_name'] = User.find(comment['to_user_id'].to_i).name
      end
      end
      respond_to do |format|
        format.json { render json: card_attributes}
        format.js {render js: "$('#notifications').load(location.href+' #notifications>*','');"}
      end
  end

  # GET /cards/new
  def new
    @card = Card.new
    if (params[:list_id][0] <= '9')
      params_list_id = params[:list_id]
    else
      params_list_id = List.where(name:params[:list_id]).first.id
    end
    @list = List.find(params_list_id)
  end

  # GET /cards/1/edit
  def edit
    @list = @card.list
  end

  # POST /cards
  # POST /cards.json
  def create
    pars = params[:card]
    @card = Card.new(card_params)
    @card.card_order = Card.where(list_id:params[:card][:list_id]).count+1
    @board = Board.find(List.find(pars[:list_id]).board.id)
    respond_to do |format|
      if @card.save
        ActionCable.server.broadcast "team_#{@card.list.board.id}_channel",
                             event: "create_card",
                             card: @card,
                             tag: @card.tags,
                             list:@card.list
        format.html { redirect_to @board, notice: 'Card was successfully created.' }
        format.json { render json: {list_id:@card.list.id}}
      else
        format.html { render :new }
        format.json { render json: @card.errors, status: :unprocessable_entity }
      end
    end
  end

  def move
    if (params[:new_list_id][0] <= '9')
      params_list_id = params[:new_list_id]
    else
      params_list_id = List.where(name:params[:new_list_id]).first.id
    end
    @moving_card = Card.find(params[:card_id])


    move_origin_cards
    old_list = @moving_card.list
    new_list = List.find(params_list_id)
    change_status old_list, new_list
    @moving_card.card_order = params[:new_position]
    @moving_card.list_id = params_list_id
    @moving_card.save
    move_new_cards
    ActionCable.server.broadcast "team_#{@moving_card.list.board.id}_channel",
                                 event: "move_card",
                                 card_id: @moving_card.id,
                                 list_id: @moving_card.list.id,
                                 order: @moving_card.card_order
    respond_to do |format|
      format.js{}
      format.json{}
      format.html{}
    end
  end

  def mulmove
    arg1 = params[:cards_id]
    i = 0
    cannot_do = "";
    while i < arg1.length
      j = i
      while j < arg1.length && arg1[j] >='0' && arg1[j] <= '9'
         j = j+1
      end
      tomov_card_id = arg1[i..j-1].to_i

      @moving_card = Card.find(tomov_card_id)
      ret = "Y"
      @moving_card.precards.each do |precard|
        if precard.list.name != "done"
          ret = "N";
          break
        end
      end
      if ret == "N"
        if cannot_do != ""
          cannot_do += ","
        end
        cannot_do += tomov_card_id.to_s
        i = j+1
        next
      end
      params_list_id = List.where(name:params[:new_list_id],board_id: @moving_card.list.board_id).first.id
      move_origin_cards
      old_list = @moving_card.list
      new_list = List.find(params_list_id)
      change_status old_list, new_list
      @moving_card.card_order = new_list.cards.count+1
      @moving_card.list_id = params_list_id
      @moving_card.save
      move_new_cards
      ActionCable.server.broadcast "team_#{@moving_card.list.board.id}_channel",
                                   event: "move_card",
                                   card_id: @moving_card.id,
                                   list_id: @moving_card.list.id,
                                   order: @moving_card.card_order
      i = j+1;

    end
    respond_to do |format|
      format.js{}
      format.json{render json: {status: "success", abortlist: cannot_do}}
      format.html{}
    end
  end




  def move_origin_cards
    origin_list_cards = Card.where("list_id = ? AND card_order > ?", @moving_card.list_id, @moving_card.card_order)
    origin_list_cards.each do |card|
      card.update(card_order: card.card_order-1)
    end
  end

  def move_new_cards
    new_list_cards = Card.where("list_id = ? AND card_order >= ?", @moving_card.list_id, @moving_card.card_order).where.not(id:@moving_card.id)
    new_list_cards.each do |card|
      card.update(card_order: card.card_order+1)
    end
  end

  def change_status old_list, new_list
    if new_list.name == 'done'
      @moving_card.finished_at = Time.now
    elsif old_list.name == 'done'
      @moving_card.finished_at = nil
    end
    if new_list.name == 'doing'
       @moving_card.startdate = Time.now
    end
  end

  def searchmember
    @thiscard = Card.find(params[:card_id].to_i)
    @current_member = @thiscard.users
  end

  def addmember
    new_member = User.find(params[:user_id].to_i)
    card = Card.find(params[:card_id])
    if card.users.include? new_member
      flash[:danger] = "User has been enrolled!"
    else
      card.users << new_member
      card.save
      n = Notification.new(recipient_id: new_member.id, card_id: card.id, read: false, source: "card")
      n.save
      CardMailer.add_user(new_member, n).deliver
    end
    ActionCable.server.broadcast "team_#{card.list.board.id}_channel",
                                 event: "add_member_to_card",
                                 card_id: card.id,
                                 user_id: new_member.id,
                                 user_name: new_member.name
    respond_to do |format|
      format.json { render json: {status: "success",member_id: new_member.id}}
    end

  end

  def deletemember
    CardEnrollment.delete(CardEnrollment.where(card_id:params[:card_id],user_id:params[:todeleteuser_id].to_i))
    card = Card.find(params[:card_id])
    user = User.find(params[:todeleteuser_id])
    ActionCable.server.broadcast "team_#{card.list.board.id}_channel",
                                 event: "delete_member_from_card",
                                 card_id: card.id,
                                 user_id: user.id,
                                 user_name: user.name
    respond_to do |format|
      format.json { render json: {status: "success",member_id: params[:todeleteuser_id]}}
    end
  end

  def edit_description
    card = Card.find(params[:card_id])
    card.description = params[:description]
    respond_to do |format|
      if card.save
        ActionCable.server.broadcast "team_#{card.list.board.id}_channel",
                                     event: "edit_card_description",
                                     card_id: card.id,
                                     description: card.description
        format.json { render json: {status: "success"}}
      else
        format.json { render json: {status: "failed"}}
      end
    end
  end


  # PATCH/PUT /cards/1
  # PATCH/PUT /cards/1.json
  def update
    respond_to do |format|
      if @card.update(card_params)
        format.html { redirect_to @card, notice: 'Card was successfully updated.' }
        format.json { render :show, status: :ok, location: @card }
      else
        format.html { render :edit }
        format.json { render json: @card.errors, status: :unprocessable_entity }
      end
    end
  end

  def search
    name = params[:search].downcase
    @cards = Card.search_cards name
    respond_to do |format|
      format.html { render(:index) }
      format.js
    end
  end

  # DELETE /cards/1
  # DELETE /cards/1.json
  def destroy
    @card.destroy
    respond_to do |format|
      format.html { redirect_to cards_url, notice: 'Card was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def can_move
    card = Card.find(params[:card_id])
    ret = "Y"
    card.precards.each do |precard|
      if precard.list.name != "done"
        ret = "N";
        break
      end
    end
    respond_to do |format|
      format.json { render json: {status: "success",canmove: ret}}
    end
  end



  private
    # Use callbacks to share common setup or constraints between actions.
    def set_card
      @card = Card.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def card_params
      params.require(:card).permit(:list_id, :content, :deadline)
    end
end
