import { ApiClient, IdmServiceApi } from "../api/src";

const apiClient = new ApiClient();
// Same-origin: the Go server serves both the SPA (/) and the API (/api/).
// Hardcoding localhost:8081 breaks any non-local deployment (e.g. Railway),
// because the *browser* would call its own localhost.
apiClient.basePath = window.location.origin;
apiClient.enableCookies = true;

const idmServiceApi = new IdmServiceApi(apiClient);

export default idmServiceApi;
