class CMDIFormat < OAI::Provider::Metadata::Format
  def initialize
    @prefix = 'oai_cmdi'
    @schema = 'https://catalog.clarin.eu/ds/ComponentRegistry/rest/registry/profiles/clarin.eu:cr1:p_1440426460262/xsd'
    @namespace = 'http://www.clarin.eu/cmd/'
  end
end