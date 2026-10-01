# frozen_string_literal: true

describe 'a locale that is not valid UTF-8', type: :request do
  let(:invalid) { "en\xC0\xA7".dup.force_encoding(Encoding::UTF_8) }

  it 'is rejected by Rails when sent as a query param' do
    get '/contact', params: { locale: invalid }

    expect(response).to have_http_status(:bad_request)
  end

  it 'falls back to the default locale when sent in the cookie' do
    cookies[:locale] = invalid
    get '/contact'

    expect(response).to have_http_status(:ok)
  end

  it 'falls back to the default locale when sent in the Accept-Language header' do
    get '/contact', headers: { 'Accept-Language' => invalid }

    expect(response).to have_http_status(:ok)
  end

  it 'falls back to the default locale when the header is binary' do
    get '/contact', headers: { 'Accept-Language' => invalid.b }

    expect(response).to have_http_status(:ok)
  end
end
