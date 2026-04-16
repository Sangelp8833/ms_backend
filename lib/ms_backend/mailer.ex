defmodule MsBackend.Mailer do
  require Logger

  @resend_url "https://api.resend.com/emails"

  def send_order_confirmation(email, tracking_code) do
    if Application.get_env(:ms_backend, :mailer_enabled, true) do
      Task.start(fn -> do_send(email, tracking_code) end)
    end
    :ok
  end

  defp do_send(email, tracking_code) do
    api_key  = Application.get_env(:ms_backend, :resend_api_key, "")
    from     = Application.get_env(:ms_backend, :resend_from, "noreply@loslibrosdivonnet.com")

    body = Jason.encode!(%{
      from:    from,
      to:      [email],
      subject: "Tu pedido ha sido recibido — Los Libros de Ivonnet",
      html:    html_body(tracking_code)
    })

    request = Finch.build(
      :post,
      @resend_url,
      [
        {"content-type", "application/json"},
        {"authorization", "Bearer #{api_key}"}
      ],
      body
    )

    case Finch.request(request, MsBackendFinch) do
      {:ok, %{status: status}} when status in 200..299 ->
        Logger.info("Email sent to #{email} for order #{tracking_code}")

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error("Email failed (#{status}): #{resp_body}")

      {:error, reason} ->
        Logger.error("Email send failed: #{inspect(reason)}")
    end
  end

  defp html_body(tracking_code) do
    """
    <div style="font-family: Georgia, serif; max-width: 520px; margin: 0 auto; padding: 32px; color: #2C1810;">
      <h1 style="color: #C4522A; font-size: 24px; margin-bottom: 8px;">
        Los Libros de Ivonnet
      </h1>
      <h2 style="font-size: 20px; margin-bottom: 16px;">¡Tu pedido fue recibido!</h2>
      <p style="color: #6B4C3B; margin-bottom: 24px;">
        Gracias por tu compra. Estamos preparando tu pedido con mucho cariño.
      </p>
      <div style="background: #FFF8EE; border: 1px solid #E8D5B7; border-radius: 12px; padding: 20px; text-align: center; margin-bottom: 24px;">
        <p style="color: #6B4C3B; font-size: 13px; margin-bottom: 8px;">Código de seguimiento</p>
        <p style="font-size: 28px; font-weight: bold; letter-spacing: 4px; color: #2C1810; font-family: monospace;">
          #{tracking_code}
        </p>
      </div>
      <p style="color: #6B4C3B; font-size: 13px;">
        Puedes usar este código en <a href="http://localhost:5174/pedido/#{tracking_code}" style="color: #C4522A;">nuestra tienda</a>
        para hacer seguimiento de tu pedido en cualquier momento.
      </p>
    </div>
    """
  end
end
