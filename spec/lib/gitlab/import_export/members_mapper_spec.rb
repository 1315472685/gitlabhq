require 'spec_helper'

describe Gitlab::ImportExport::MembersMapper do
  describe 'map members' do
    let(:user) { create(:admin) }
    let(:project) { create(:project, :public, name: 'searchable_project') }
    let(:user2) { create(:user) }
    let(:exported_user_id) { 99 }
    let(:exported_members) do
      [{
         "id" => 2,
         "access_level" => 40,
         "source_id" => 14,
         "source_type" => "Project",
         "user_id" => 19,
         "notification_level" => 3,
         "created_at" => "2016-03-11T10:21:44.822Z",
         "updated_at" => "2016-03-11T10:21:44.822Z",
         "created_by_id" => nil,
         "invite_email" => nil,
         "invite_token" => nil,
         "invite_accepted_at" => nil,
         "user" =>
           {
             "id" => exported_user_id,
             "email" => user2.email,
             "username" => 'test'
           }
       },
       {
         "id" => 3,
         "access_level" => 40,
         "source_id" => 14,
         "source_type" => "Project",
         "user_id" => nil,
         "notification_level" => 3,
         "created_at" => "2016-03-11T10:21:44.822Z",
         "updated_at" => "2016-03-11T10:21:44.822Z",
         "created_by_id" => 1,
         "invite_email" => 'invite@test.com',
         "invite_token" => 'token',
         "invite_accepted_at" => nil
       }]
    end

    let(:members_mapper) do
      described_class.new(
        exported_members: exported_members, user: user, project: project)
    end

    it 'includes the exported user ID in the map' do
      expect(members_mapper.map.keys).to include(exported_user_id)
    end

    it 'maps a project member' do
      expect(members_mapper.map[exported_user_id]).to eq(user2.id)
    end

    it 'defaults to importer project member if it does not exist' do
      expect(members_mapper.map[-1]).to eq(user.id)
    end

    it 'has invited members with no user' do
      members_mapper.map

      expect(ProjectMember.find_by_invite_email('invite@test.com')).not_to be_nil
    end

    it 'authorizes the users to the project' do
      members_mapper.map

      expect(user.authorized_project?(project)).to be true
      expect(user2.authorized_project?(project)).to be true
    end

    it 'maps an owner as a maintainer' do
      exported_members.first['access_level'] = ProjectMember::OWNER

      expect(members_mapper.map[exported_user_id]).to eq(user2.id)
      expect(ProjectMember.find_by_user_id(user2.id).access_level).to eq(ProjectMember::MAINTAINER)
    end

    context 'user is not an admin' do
      let(:user) { create(:user) }

      it 'does not map a project member' do
        expect(members_mapper.map[exported_user_id]).to eq(user.id)
      end

      it 'defaults to importer project member if it does not exist' do
        expect(members_mapper.map[-1]).to eq(user.id)
      end
    end

    context 'chooses the one with an email first' do
      let(:user3) { create(:user, username: 'test') }

      it 'maps the project member that has a matching email first' do
        expect(members_mapper.map[exported_user_id]).to eq(user2.id)
      end
    end

    context 'importer same as group member' do
      let(:user2) { create(:admin) }
      let(:group) { create(:group) }
      let(:project) { create(:project, :public, name: 'searchable_project', namespace: group) }
      let(:members_mapper) do
        described_class.new(
          exported_members: exported_members, user: user2, project: project)
      end

      before do
        group.add_users([user, user2], GroupMember::DEVELOPER)
      end

      it 'maps the project member' do
        expect(members_mapper.map[exported_user_id]).to eq(user2.id)
      end

      it 'maps the project member if it already exists' do
        project.add_maintainer(user2)

        expect(members_mapper.map[exported_user_id]).to eq(user2.id)
      end
    end

    context 'importing group members' do
      let(:group) { create(:group) }
      let(:project) { create(:project, namespace: group) }
      let(:members_mapper) do
        described_class.new(
          exported_members: exported_members, user: user, project: project)
      end

      before do
        group.add_users([user, user2], GroupMember::DEVELOPER)
        user.update(email: 'invite@test.com')
      end

      it 'maps the importer' do
        expect(members_mapper.map[-1]).to eq(user.id)
      end

      it 'maps the group member' do
        expect(members_mapper.map[exported_user_id]).to eq(user2.id)
      end
    end
  end
end
