require File.expand_path(File.join(File.dirname(__FILE__), "../integration_test_helper.rb"))
require "resque_jobs/deliver_commit_emails"
require "test/db_fixtures_helper"

class DeliverCommitEmailsIntegrationTest < Scope::TestCase
  include IntegrationTestHelper

  setup_once do
    commit = test_repo.commits("9f9c5d87316e5f723d0e9c6a03ddd86ce134ac5e")[0]
    Commit.filter(:sha => commit.sha).destroy
    @@commit = create_commit(commit, integration_test_user, GitRepo.first(:name => TEST_REPO_NAME))

    @@saved_search = SavedSearch.create(:user_id => integration_test_user.id, :repos => TEST_REPO_NAME,
        :email_commits => true, :user_order => 0)
  end

  teardown_once do
    # Destroying the commit destroys any associated comments.
    @@commit.destroy
    @@saved_search.destroy
  end

  setup do
    @mail_options = nil
    stub(Pony).mail { |options| @mail_options = options }
  end

  should "deliver an email containing a commit" do
    # Limit the saved searches which are retrieved to ones owned by this user. We don't to send spurious
    # emails to users from tests.
    dataset = SavedSearch.dataset.filter(:user_id => integration_test_user.id)
    stub(SavedSearch).filter { dataset }
    DeliverCommitEmails.perform(TEST_REPO_NAME, @@commit.sha)
    assert_equal integration_test_user.email, @mail_options[:to]
    assert @mail_options[:subject].include?(@@commit.grit_commit.id_abbrev)
  end
end
