module ApplicationHelper
  def nav_link_to(text, path, **options)
    link_to text, path, **options.merge(aria_current: current_page?(path) ? "page" : nil)
  end
end
