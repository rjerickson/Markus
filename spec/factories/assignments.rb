require 'faker'

FactoryGirl.define do
  factory :assignment do
    sequence(:short_identifier) { |i| "A#{i}" }
    description { Faker::Lorem.sentence }
    message { Faker::Lorem.sentence }
    group_min 1
    group_max 1
    student_form_groups false
    group_name_autogenerated true
    group_name_displayed false
    repository_folder { Faker::Lorem.word }
    due_date 1.minute.from_now
    marking_scheme_type Assignment::MARKING_SCHEME_TYPE[:rubric]
    allow_web_submits true
    display_grader_names_to_students false
    submission_rule { NoLateSubmissionRule.new }
    assignment_stat { AssignmentStat.new }
    token_period 1
    tokens_per_period 0
    unlimited_tokens false
    enable_test false

    factory :flexible_assignment do
      marking_scheme_type Assignment::MARKING_SCHEME_TYPE[:flexible]
    end

    factory :rubric_assignment do
      marking_scheme_type Assignment::MARKING_SCHEME_TYPE[:rubric]
    end
  end
end
