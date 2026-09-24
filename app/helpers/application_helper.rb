module ApplicationHelper
  def nav_link_to(text, path, **options)
    if current_page?(path)
      link_to text, path, **options.merge("aria-current": "page")
    else
      link_to text, path, **options
    end
  end
end
