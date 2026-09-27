module ApplicationHelper
  def nav_link_to(text, path, current: current_page?(path), **options)
    if current
      link_to text, path, **options.merge("aria-current": "page")
    else
      link_to text, path, **options
    end
  end
end
