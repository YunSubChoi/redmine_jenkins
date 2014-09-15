class JenkinsJob < ActiveRecord::Base
  unloadable

  ## Relations
  belongs_to :project
  belongs_to :repository
  belongs_to :jenkins_setting
  has_many   :builds, dependent: :destroy, class_name: 'JenkinsBuild'

  ## Validations
  validates_presence_of   :project_id, :repository_id, :jenkins_setting_id, :name
  validates_uniqueness_of :name, :scope => :jenkins_setting_id

  ## Serialization
  serialize :health_report, Array

  ## Delegate
  delegate :jenkins_connection, :wait_for_build_id, to: :jenkins_setting


  def url
    "#{self.jenkins_setting.url}/job/#{self.name}"
  end


  def latest_build_url
    "#{self.jenkins_setting.url}/job/#{self.name}/#{self.latest_build_number}"
  end


  def build
    build_number = ""
    opts = {}
    opts['build_start_timeout'] = 30 if wait_for_build_id

    begin
      build_number = jenkins_connection.job.build(name, {}, opts)
    rescue => e
      error   = true
      content = "#{l(:error_jenkins_connection)} : #{e.message}"
    else
      error = false
    end

    if !error
      if wait_for_build_id
        self.latest_build_number = build_number
        content = l(:label_build_accepted, :job_name => self.name, :build_id => ": '#{build_number}'")
      else
        content = l(:label_build_accepted, :job_name => self.name, :build_id => '')
      end

      self.state = 'running'
      self.save!
      self.reload
    end

    return error, content
  end


  def console
    begin
      console_output = jenkins_connection.job.get_console_output(self.name, self.latest_build_number)['output'].gsub('\r\n', '<br />')
    rescue => e
      console_output = e.message
    end
    return console_output
  end

end
