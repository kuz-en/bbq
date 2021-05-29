class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:facebook, :vkontakte]

  has_many :events, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :subscriptions, dependent: :destroy

  validates :name, presence: true, length: { maximum: 35 }

  validates :email, presence: true, uniqueness: true

  before_validation :set_name, on: :create

  after_commit :link_subscriptions, on: :create

  mount_uploader :avatar, AvatarUploader

  def self.find_for_oauth(access_token)
    email = access_token.info.email
    user = where(email: email).first


    provider = access_token.provider
    id = access_token.extra.raw_info.id

    case provider
    when 'facebook'
      url = "https://facebook.com/#{id}"
      avatar = "#{access_token.info.image}?type=large".gsub('http', 'https')
    when 'vkontakte'
      url = "https://vk.ru/#{id}"
      avatar = access_token.info.image
    end

    return user && update_avatar(user, avatar) if user.present?

    where(url: url, provider: provider).first_or_create! do |user|
      user.email = email
      user.password = Devise.friendly_token.first(16)
      user.remote_avatar_url = avatar
    end
  end

  private

  def set_name
    self.name = 'Незнакомец' if self.name.blank?
  end

  def link_subscriptions
    Subscription.where(user_id: nil, user_email: self.email)
                .update_all(user_id: self.id)
  end
end

def update_avatar(user, avatar)
  user.update(remote_avatar_url: avatar) unless user.avatar.present?
end
