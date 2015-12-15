#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>


typedef struct {
    ngx_msec_t                         res_time;
    ngx_str_t                          *server;
} ngx_http_upstream_labor_point_t;

typedef struct {
    ngx_uint_t                          number;
    ngx_http_upstream_labor_point_t     point[1];
} ngx_http_upstream_labor_points_t;

typedef struct {
    /* the round robin data must be first */
    ngx_http_upstream_rr_peer_data_t   rrp;
    ngx_http_request_t                *request;
    ngx_http_upstream_labor_points_t  *points;
    ngx_msec_t                         last_response_time;

    ngx_uint_t                         hash;

    u_char                             addrlen;
    u_char                            *addr;

    u_char                             tries;

    ngx_event_get_peer_pt              get_rr_peer;
    
} ngx_http_upstream_labor_peer_data_t;

static ngx_int_t ngx_http_upstream_init_labor_peer(ngx_http_request_t *r,
    ngx_http_upstream_srv_conf_t *us);
static ngx_int_t ngx_http_upstream_get_labor_peer(
    ngx_peer_connection_t *pc, void *data);
static void ngx_http_upstream_free_labor_peer(
    ngx_peer_connection_t *pc, void *data, ngx_uint_t state);
static char *ngx_http_upstream_labor(ngx_conf_t *cf, ngx_command_t *cmd,
    void *conf);

static ngx_command_t  ngx_http_upstream_labor_commands[] = {

    { ngx_string("labor"),
      NGX_HTTP_UPS_CONF|NGX_CONF_NOARGS,
      ngx_http_upstream_labor,
      0,
      0,
      NULL },

      ngx_null_command
};


static ngx_http_module_t  ngx_http_upstream_labor_module_ctx = {
    NULL,                                  /* preconfiguration */
    NULL,                                  /* postconfiguration */

    NULL,                                  /* create main configuration */
    NULL,                                  /* init main configuration */

    NULL,                                  /* create server configuration */
    NULL,                                  /* merge server configuration */

    NULL,                                  /* create location configuration */
    NULL                                   /* merge location configuration */
};


ngx_module_t  ngx_http_upstream_labor_module = {
    NGX_MODULE_V1,
    &ngx_http_upstream_labor_module_ctx, /* module context */
    ngx_http_upstream_labor_commands, /* module directives */
    NGX_HTTP_MODULE,                       /* module type */
    NULL,                                  /* init master */
    NULL,                                  /* init module */
    NULL,                                  /* init process */
    NULL,                                  /* init thread */
    NULL,                                  /* exit thread */
    NULL,                                  /* exit process */
    NULL,                                  /* exit master */
    NGX_MODULE_V1_PADDING
};


static ngx_int_t
ngx_http_upstream_init_labor(ngx_conf_t *cf,
    ngx_http_upstream_srv_conf_t *us)
{
    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, cf->log, 0,
                   "init labor");

    if (ngx_http_upstream_init_round_robin(cf, us) != NGX_OK) {
        return NGX_ERROR;
    }

    us->peer.init = ngx_http_upstream_init_labor_peer;

    return NGX_OK;
}


static ngx_int_t
ngx_http_upstream_init_labor_peer(ngx_http_request_t *r,
    ngx_http_upstream_srv_conf_t *us)
{
    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "init labor peer");

    ngx_http_upstream_labor_peer_data_t  *lp;
    ngx_http_upstream_labor_points_t   *points;

    lp = ngx_palloc(r->pool, sizeof(ngx_http_upstream_labor_peer_data_t));
    if (lp == NULL) {
        return NGX_ERROR;
    }

    lp->request = r;
    lp->last_response_time = 1;

    r->upstream->peer.data = &lp->rrp;

    if (ngx_http_upstream_init_round_robin_peer(r, us) != NGX_OK) {
        return NGX_ERROR;
    }

    ngx_http_upstream_rr_peers_t *rr_peers = us->peer.data;

    ngx_uint_t primary_peers_num = rr_peers->number;

    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "fucking init peer, cnt: %ui", rr_peers->number);

    points = lp->points;

    size_t size = sizeof(ngx_http_upstream_labor_points_t)
           + sizeof(ngx_http_upstream_labor_point_t) * (primary_peers_num - 1);

    points = ngx_palloc(r->pool, size);

    points->number = primary_peers_num;
    ngx_uint_t n = 0;
    ngx_http_upstream_rr_peer_t        *peer;
    for(peer = rr_peers->peer; peer; peer = peer->next, n++) {
        ngx_str_t                          *server;
        server = &peer->server;
        points->point[n].server = server;
        points->point[n].res_time = 0;
    }

    lp->points = points;
    
    r->upstream->peer.get = ngx_http_upstream_get_labor_peer;
    r->upstream->peer.free = ngx_http_upstream_free_labor_peer;

    //hcf = ngx_http_conf_upstream_srv_conf(us, ngx_http_upstream_hash_module);

    return NGX_OK;
}

static void
ngx_http_upstream_free_labor_peer(ngx_peer_connection_t *pc, void *data,
    ngx_uint_t state)
{
    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                   "fucking free peer");

    ngx_http_upstream_labor_peer_data_t *lp = data;

    ngx_http_request_t *r = lp->request;

    if (r->upstream) {
        ngx_log_debug0(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                   "fucking 1");
    }
    if (r->upstream && r->upstream->state) {
        ngx_log_debug0(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                   "fucking 2");
    }
    if (r->upstream && r->upstream->state && r->upstream->state->response_time) {
        ngx_log_debug0(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                   "fucking 3");
        ngx_log_debug1(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                   "fucking 4: %ui", r->upstream->state->response_time);
        ngx_log_debug1(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                   "fucking 4: %p", lp->rrp.current);
        ngx_log_debug1(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                   "fucking 4: %V", &(lp->rrp.current->name));
        ngx_msec_t response_time = r->upstream->state->response_time;
        if (lp->last_response_time) {
            ngx_log_debug1(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                   "fucking 5: %ui", lp->last_response_time);
        }
        lp->last_response_time = response_time;

    }

    ngx_http_upstream_free_round_robin_peer(pc, data, state);
}


static ngx_int_t
ngx_http_upstream_get_labor_peer(ngx_peer_connection_t *pc, void *data)
{
    //ngx_http_upstream_labor_peer_data_t *lp = data;

    ngx_int_t result = ngx_http_upstream_get_round_robin_peer(pc, data);

    return result;
}


static char *
ngx_http_upstream_labor(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_http_upstream_srv_conf_t  *uscf;

    uscf = ngx_http_conf_get_module_srv_conf(cf, ngx_http_upstream_module);

    if (uscf->peer.init_upstream) {
        ngx_conf_log_error(NGX_LOG_WARN, cf, 0,
                           "load balancing method redefined");
    }

    uscf->peer.init_upstream = ngx_http_upstream_init_labor;

    uscf->flags = NGX_HTTP_UPSTREAM_CREATE
                  |NGX_HTTP_UPSTREAM_WEIGHT
                  |NGX_HTTP_UPSTREAM_MAX_FAILS
                  |NGX_HTTP_UPSTREAM_FAIL_TIMEOUT
                  |NGX_HTTP_UPSTREAM_DOWN
                  |NGX_HTTP_UPSTREAM_BACKUP;

    return NGX_CONF_OK;
}
