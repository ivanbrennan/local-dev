let
  kubeVersion = "1.14";

  mkApp = appName: rec {
    label = appName;
    port = 8080;
    cpu = "100m";
    imagePolicy = "Never";
    env = [
      {
        name = "APP_PORT";
        value = toString port;
      }
      {
        name = "APP_NAME";
        value = appName;
      }
    ];
  };

  mkDeployment = app: {
    metadata.labels.app = app.label;
    spec = {
      replicas = 1;
      selector.matchLabels.app = app.label;
      template = {
        metadata.labels.app = app.label;
        spec.containers."${app.label}" = {
          name = app.label;
          image = "hello-app:latest";
          imagePullPolicy = app.imagePolicy;
          env = app.env;
          resources.requests.cpu = app.cpu;
          ports."${toString app.port}" = {};
        };
      };
    };
  };

  mkService = app: {
    spec.selector.app = app.label;
    spec.ports."${toString app.port}".targetPort = app.port;
  };

  helloApp = mkApp "hello";

  hiApp = mkApp "hi";
in
  {
    kubernetes.version = kubeVersion;

    kubernetes.resources.deployments."${helloApp.label}" = mkDeployment helloApp;
    kubernetes.resources.deployments."${hiApp.label}" = mkDeployment hiApp;

    kubernetes.resources.services."${helloApp.label}" = mkService helloApp;
    kubernetes.resources.services."${hiApp.label}" = mkService hiApp;

    kubernetes.resources.ingresses.hello-ingress = {
      metadata.labels.app = "hello";
      metadata.annotations = {
        "nginx.ingress.kubernetes.io/rewrite-target" = "/$2";
      };
      spec.rules = [
        {
          http.paths = [
            {
              path = "/hello(/|$)(.*)";
              backend = {
                serviceName = helloApp.label;
                servicePort = helloApp.port;
              };
            }
            {
              path = "/hi(/|$)(.*)";
              backend = {
                serviceName = hiApp.label;
                servicePort = hiApp.port;
              };
            }
          ];
        }
      ];
    };
  }
