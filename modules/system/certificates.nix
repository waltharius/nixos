{...}: {
  # Internal Certificates Authorities
  # These certificates are required for accessing internal infrastructure (homelab)

  security.pki.certificates = [
    # FreeIPA CA
    # Domain: home.lan
    # Used by: Atuin server (atuin.home.lan)
    # To update: curl -o /tmp/ipa-ca.crt http://ipa.home.lan/ipa/config/ca.crt
    ''
      -----BEGIN CERTIFICATE-----
      MIIERDCCAqygAwIBAgIBATANBgkqhkiG9w0BAQsFADAzMREwDwYDVQQKDAhIT01F
      LkxBTjEeMBwGA1UEAwwVQ2VydGlmaWNhdGUgQXV0aG9yaXR5MB4XDTI1MDkwNzIx
      MDYxMloXDTQ1MDkwNzIxMDYxMlowMzERMA8GA1UECgwISE9NRS5MQU4xHjAcBgNV
      BAMMFUNlcnRpZmljYXRlIEF1dGhvcml0eTCCAaIwDQYJKoZIhvcNAQEBBQADggGP
      ADCCAYoCggGBALSFVIdMcu83Ts+EZ5jTKxpoRqDTMxkG+ofet8dThq9HQzlmB9dk
      I50481CZDj0HEmqx8bvqtMvYh+OgSGpsxkudR6m0yvzUIRgbHcL3Lu5FL5lew0TH
      Hop2185AzNNNzNAHFwrzwsrh24SdYp/yQKNuEzo+UBW4ud35GmqJ1dhuQBbwPVDG
      GBFqtu8HDzClsPR9da60AFRlihPxApzXsMhh02AjIiUikCZ7w3Gi21MTicchE6En
      /olu9fS4E3OqEWuBa9vX1AjtMHdRdoPhyixPthCo7Gx8kkCdm9F7I8sxltHfLR15
      VOIziZOu1PPkaN6Y48UwcjQ7bUbNKhcPNbpdmM3CVRMdjuHKBBkdqtPR7III+w99
      zKuTl6DB3tJFYEsUsJ6zgPRGsSdYEkHPEF8+QrXaifz7/HpQcqOyGCtYhz69dnNv
      lOTXhbzQZQVMtVsHgA3ez8i425WcR6dzowvGT2Z4Wt53eq2rIjvrvgvRX/x5xBkV
      ma0XQnoA3W4PUQIDAQABo2MwYTAdBgNVHQ4EFgQUVO/HHNi71WpXAPikCgRYRqcv
      hCMwHwYDVR0jBBgwFoAUVO/HHNi71WpXAPikCgRYRqcvhCMwDwYDVR0TAQH/BAUw
      AwEB/zAOBgNVHQ8BAf8EBAMCAcYwDQYJKoZIhvcNAQELBQADggGBACD+Yna8KdEK
      yT7FzszvY34NRLA/pOqPTYanL4zskdkN7/RAS02beEMRGCsPrrSRJi5K3o7/ABLj
      jOBTw4f4E2dBVVtIvBgdy3UH+O3QzdDAJCrgeqgqcwYfH5YnaFQpcnVC72qJy9Qt
      B37Tv6B/LbqmH695y+lm3O6j9LIb1Q9XdaiMZ/RHYu65sbVt3Mgk8Wl7eyqEiZsS
      DphRKIxDXKDkoPGPvl0xrvY1MxJOSY5W6YAxMoPbvh9LzoH5cQupOI5VnTMj2U5t
      abQ/++XFcVIhJYTOiSzrswCC5bMUPM7UjSCtohiJbu7SGFJdqhUoPUKpRM0l3Md5
      xHa8KyP6EeUs1nGvOgvFjpQBfM09ecohif2HJ0OkEIM4ENbJKKy6NlNhaxA3VsX9
      qgC1/zWsjRfy5uqQDI5hHi1LeTWUsM5geWC9BdBcDAW3mmIeoKcI1MuQkGevdc71
      6ZwEKtNeWK/GTR7WNJckz3wSkXAL29TVuUdDoK85QF1nrzFuBQ+N3w==
      -----END CERTIFICATE-----
    ''
  ];
}
