include ActionDispatch::TestProcess

FactoryBot.define do
  factory :ci_job_artifact, class: Ci::JobArtifact do
    job factory: :ci_build
    file_type :archive
    file_format :zip

    trait :remote_store do
      file_store JobArtifactUploader::Store::REMOTE
    end

    after :build do |artifact|
      artifact.project ||= artifact.job.project
    end

    trait :archive do
      file_type :archive
      file_format :zip

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/ci_build_artifacts.zip'), 'application/zip')
      end
    end

    trait :metadata do
      file_type :metadata
      file_format :gzip

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/ci_build_artifacts_metadata.gz'), 'application/x-gzip')
      end
    end

    trait :trace do
      file_type :trace
      file_format :raw

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/trace/sample_trace'), 'text/plain')
      end
    end

    trait :junit do
      file_type :junit
      file_format :gzip

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/junit/junit.xml.gz'), 'application/x-gzip')
      end
    end

    trait :junit_with_ant do
      file_type :junit
      file_format :gzip

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/junit/junit_ant.xml.gz'), 'application/x-gzip')
      end
    end

    trait :junit_with_three_testsuites do
      file_type :junit
      file_format :gzip

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/junit/junit_with_three_testsuites.xml.gz'), 'application/x-gzip')
      end
    end

    trait :junit_with_corrupted_data do
      file_type :junit
      file_format :gzip

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/junit/junit_with_corrupted_data.xml.gz'), 'application/x-gzip')
      end
    end

    trait :correct_checksum do
      after(:build) do |artifact, evaluator|
        artifact.file_sha256 = Digest::SHA256.file(artifact.file.path).hexdigest
      end
    end
  end
end
