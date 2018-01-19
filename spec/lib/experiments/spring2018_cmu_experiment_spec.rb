# frozen_string_literal: true

require 'rails_helper'
require "#{Rails.root}/lib/experiments/spring2018_cmu_experiment"

describe Spring2018CmuExperiment do
  let(:spring_2018) { create(:campaign, slug: 'spring_2018') }
  let(:user) { create(:user, email: 'sage@example.com') }

  before do
    4.times do |i|
      course = create(:course, slug: "spring course number #{i}", id: i)
      course.campaigns << spring_2018
      create(:courses_user, course: course, user: user,
                            role: CoursesUsers::Roles::INSTRUCTOR_ROLE)
    end
  end

  describe '.process_courses' do
    it 'divides courses between experiment and control, and updates experiment setting' do
      Spring2018CmuExperiment.process_courses
      control_courses = Course.all.select do |c|
        c.flags[Spring2018CmuExperiment::STATUS_KEY] == 'control'
      end
      expect(control_courses.count).to eq(1)
      emailed_courses = Course.all.select do |c|
        c.flags[Spring2018CmuExperiment::STATUS_KEY] == 'email_sent'
      end
      expect(emailed_courses.count).to eq(3)
      experiment_setting = Setting.find_by(key: 'spring_2018_cmu_experiment')
      expect(experiment_setting.value[:enrolled_courses_count]).to eq(4)
    end

    context 'when invitations get no response for a week' do
      after { Timecop.return }
      it 'sends reminders for courses that have not responded' do
        Spring2018CmuExperiment.process_courses
        Timecop.travel(8.days.from_now)
        Spring2018CmuExperiment.process_courses
        reminded_courses = Course.all.select do |c|
          c.flags[Spring2018CmuExperiment::STATUS_KEY] == 'reminder_sent'
        end
        expect(reminded_courses.count).to eq(3)
      end
    end
  end

  let(:course) { create(:course, flags: { Spring2018CmuExperiment::STATUS_KEY => 'email_sent' }) }

  describe '#opt_in and #opt_out' do
    it 'updates the experiment status of a course to opted_in' do
      Spring2018CmuExperiment.new(course).opt_in
      expect(course.flags[Spring2018CmuExperiment::STATUS_KEY]).to eq('opted_in')
    end
  end

  describe '#opt_out' do
    it 'updates the experiment status of a course to opted_out' do
      Spring2018CmuExperiment.new(course).opt_out
      expect(course.flags[Spring2018CmuExperiment::STATUS_KEY]).to eq('opted_out')
    end
  end
end