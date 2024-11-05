require "faraday"
require "dotenv/load"

class Guardian

  def initialize(membership_id)
    @membership_id = membership_id
  end

end

class BungieApiClient
  attr_reader :conn

  X_API_KEY = ENV['X_API_KEY']
  MEMBERSHIP_TYPE = -1 # All memberships

  def initialize
    @conn = connection
  end

  def connection
    Faraday.new(
      url: "https://www.bungie.net",
      headers: {
        'Content-Type' => 'application/json',
        'X-API-Key' => X_API_KEY
      }
    )
  end

  def search_destiny_player_by_bungie_name(display_name:, display_name_code:)
    conn.post("/Platform/Destiny2/SearchDestinyPlayerByBungieName/#{MEMBERSHIP_TYPE}/") do |req|
      req.body = {
        'displayName' => "#{display_name}",
        'displayNameCode' => "#{display_name_code}"
      }.to_json
    end
  end

  def search_by_global_name(player_name:)
    page = 0

    response = conn.post("/Platform/User/Search/GlobalName/#{page}/") do |req|
      req.body = { 'displayNamePrefix' => "#{player_name}" }.to_json
    end

    JSON.parse(response.body)["Response"]
  end

  def get_profile(membership_type:, membership_id:)
    component_arguments = {
      profiles: '100',
      characters: '200',
      character_activities: '204'
    }.values.join(',')

    conn.get("/Platform/Destiny2/#{membership_type}/Profile/#{membership_id}/") do |req|
      req.params['components'] = component_arguments
    end
  end

end

class GuardianClient
  attr_reader :client

  def initialize
    @client = BungieApiClient.new
  end

  def call
    membership = search_membership_info_for_player

    client.get_profile(**membership.to_h)
  end

  private

  # https://www.bungie.net/Platform/Destiny2/1/Profile/4611686018434249462/?components=100%2C200%2C204
  # https://www.bungie.net/Platform/Destiny2/1/Profile/4611686018434249462?components=100%2C200%2C204

  def search_membership_info_for_player(search_name: "kaiuzo")
    player_search = client.search_by_global_name(player_name: search_name)

    membership_type = player_search.dig("searchResults", 0, "destinyMemberships", 0, "membershipType")
    membership_id = player_search.dig("searchResults", 0, "destinyMemberships", 0, "membershipId")

    membership_struct(type: membership_type, id: membership_id)
  end

  def membership_struct(type:, id:)
    OpenStruct.new(
      {
        :membership_type => type,
        :membership_id => id
      }
    )
  end

  def get_all_characters(membership_ids:)
    membership_ids
  end

end

gc = GuardianClient.new
pp gc.call

# 1. Search for player + pluck membership ID
def pluck_membership_id(page: 0, player_name:, conn: connection)
  response = conn.post("/Platform/User/Search/GlobalName/#{page}/") do |req|
    req.body = { 'displayNamePrefix' => "#{player_name}" }.to_json
  end

  response_body = JSON.parse(response.body)

  # response_body["Response"]["searchResults"][0]["bungieNetMembershipId"]
  response_body.dig("Response", "searchResults", 0, "bungieNetMembershipId")
end

def search_player_by_bungie_name(display_name:, display_name_code:, conn: connection)
  conn.post("/Platform/Destiny2/SearchDestinyPlayerByBungieName/#{MEMBERSHIP_TYPE}/") do |req|
    req.body = {
      'displayName' => "#{display_name}",
      'displayNameCode' => "#{display_name_code}"
    }.to_json
  end
end

def get_activity_history(conn: connection, destiny_membership_id:, character_id:)
  conn.get("/Platform/Destiny2/#{MEMBERSHIP_TYPE}/Account/#{destiny_membership_id}/Character/#{character_id}/Stats/Activities/") do |req|
    req.params = {}
  end
end

def get_player(bnet_membership_id, conn: connection)
  response = conn.get("/Platform/User/GetBungieNetUserById/#{bnet_membership_id}/") do |req|
    req.params = {}
  end

  response_body = JSON.parse(response.body)
  # pp response_body

  OpenStruct.new(response_body['Response'])
end

def response_helper(response)
  # pp response

  response_data = {
    :status => response.status,
    :body => JSON.parse(response.body),
    :reason => response.reason_phrase
  }

  pp response_data
end

# --- Manual Calls ---

# res = search_player(player_name: "kaiuzo")
# response_helper(res)
#
# res2 = search_player_by_bungie_name(display_name: "kaiuzo", display_name_code: 8294)
# response_helper(res2)
#
# res3 = get_player(id, conn: connection)
# response_helper(res3)

# mem_id = pluck_membership_id(player_name: "kaiuzo")
#
# get_player_response = get_player(mem_id, conn: connection)
# pp get_player_response
# get_activity_history_response = get_activity_history(
#   destiny_membership_id: get_player_response.membershipId,
#   character_id:
# )
