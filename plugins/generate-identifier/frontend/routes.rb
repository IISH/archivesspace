ArchivesSpace::Application.routes.draw do
  [AppConfig[:frontend_proxy_prefix], AppConfig[:frontend_prefix]].uniq.each do |prefix|

  scope prefix do
  match('/plugins/generate_identifier/generate' => 'generate_identifier#generate',
        :via => [:post])
  end
 end
end
