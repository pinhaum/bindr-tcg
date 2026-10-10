class Api::CardsController < Api::BaseController
  allow_unauthenticated_access

  def show
    @detail = CardDetail.new(card_number: params[:card_number], user: Current.user,
                             requested_variant: params[:variant]).call
  end
end
