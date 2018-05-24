module Groups
  class SharedProjectsController < Groups::ApplicationController
    respond_to :json
    before_action :group
    skip_cross_project_access_check :index

    def index
      shared_projects = GroupProjectsFinder.new(
        group: group,
        current_user: current_user,
        params: finder_params,
        options: { only_shared: true }
      ).execute
      serializer = GroupChildSerializer.new(current_user: current_user)
                     .with_pagination(request, response)

      render json: serializer.represent(shared_projects)
    end

    private

    def finder_params
      @finder_params ||= begin
                           # Make the `search` param consitent for the frontend,
                           # which will be using `filter`.
                           params[:search] ||= params[:filter] if params[:filter]
                           params.permit(:sort, :search)
                         end
    end
  end
end
