# frozen_string_literal: true

shared_context 'action view' do
  subject { action_view.render(template: super().delete_suffix('.html.erb')) }
  let(:action_view) { ActionView::Base.with_empty_template_cache.new(context, assigns, nil) }
  let(:context) { ActionView::LookupContext.new(File.join(Dir.pwd, 'views')) }
end
