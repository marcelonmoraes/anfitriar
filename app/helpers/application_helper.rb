module ApplicationHelper
  def nav_link(label, path, id)
    active = current_page?(path)
    classes = "nav-link px-3 py-1.5 rounded-lg font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-gray-900 focus:ring-offset-2 #{active ? 'bg-gray-100 text-gray-900' : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'}"
    link_to label, path, class: classes, id: id, "aria-current": active ? "page" : nil
  end
end
