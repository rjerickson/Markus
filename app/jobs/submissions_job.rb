class SubmissionsJob < ActiveJob::Base
  queue_as :submissions

  before_enqueue do |_job|
    job_messenger = JobMessenger.create(job_id: job_id, status: :queued)
    PopulateCache.populate_for_job(job_messenger, job_id)
  end

  def perform(groupings, options = {})
    return if groupings.empty?

    m_logger = MarkusLogger.instance
    assignment = groupings.first.assignment

    begin
      job_messenger = JobMessenger.where(job_id: job_id).first
      unless job_messenger.nil?
        job_messenger.update(status: :running)
        PopulateCache.populate_for_job(job_messenger, job_id)
      end

      m_logger.log('Submission collection process established database' +
                   ' connection successfully')

      groupings.each do |grouping|
        m_logger.log("Now collecting: #{assignment.short_identifier} for grouping: " +
                     "#{grouping.id}")

        if options[:revision_number].nil?
          time = assignment.submission_rule.calculate_collection_time.localtime
          new_submission = Submission.create_by_timestamp(grouping, time)
        else
          new_submission = Submission.create_by_revision_number(grouping, options[:revision_number])
        end

        if assignment.submission_rule.is_a? GracePeriodSubmissionRule
          # Return any grace credits previously deducted for this grouping.
          assignment.submission_rule.remove_deductions(grouping)
        end

        if options[:apply_late_penalty].nil? || options[:apply_late_penalty]
          new_submission = assignment.submission_rule.apply_submission_rule(
            new_submission)
        end

        unless grouping.error_collecting
          grouping.is_collected = true
        end

        grouping.save

        # Request a test run for the grouping
        request_a_test_run(grouping, new_submission)
      end
      m_logger.log('Submission collection process done')
    rescue => e
      Rails.logger.error e.message
      unless job_messenger.nil?
        job_messenger.update(status: :failed, message: e.message)
        PopulateCache.populate_for_job(job_messenger, job_id)
      end
      raise e
    end
    unless job_messenger.nil?
      job_messenger.update(status: :succeeded)
      PopulateCache.populate_for_job(job_messenger, job_id)
    end
  end

  def request_a_test_run(grouping, new_submission)
    m_logger = MarkusLogger.instance
    if grouping.assignment.enable_test
      m_logger.log("Now requesting test run for #{grouping.assignment.short_identifier} \
                    on grouping: '#{grouping.id}'")
      AutomatedTestsHelper.request_a_test_run(new_submission.grouping.id,
                                              'collection',
                                              @current_user,
                                              new_submission.id)
    end
  end
end
