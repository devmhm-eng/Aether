// +build ignore

#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/udp.h>
#include <linux/in.h>
#include <bpf/bpf_helpers.h>

// Aether Magic Knock: 0xDEADBEEF at payload offset 0
// Real implementation would be encrypted.
#define MAGIC_KNOCK 0xDEADBEEF

struct {
	__uint(type, BPF_MAP_TYPE_XSKMAP);
	__uint(max_entries, 64);
	__type(key, int);
	__type(value, int);
} xsks_map SEC(".maps");

SEC("xdp")
int aether_filter(struct xdp_md *ctx) {
	void *data_end = (void *)(long)ctx->data_end;
	void *data = (void *)(long)ctx->data;

	struct ethhdr *eth = data;
	if (data + sizeof(*eth) > data_end)
		return XDP_PASS;

	if (eth->h_proto != __constant_htons(ETH_P_IP))
		return XDP_PASS;

	struct iphdr *ip = data + sizeof(*eth);
	if (data + sizeof(*eth) + sizeof(*ip) > data_end)
		return XDP_PASS;

	if (ip->protocol != IPPROTO_UDP)
		return XDP_PASS;

	struct udphdr *udp = (void *)ip + sizeof(*ip);
	if ((void *)udp + sizeof(*udp) > data_end)
		return XDP_PASS;

	// Check Payload (Knock)
	unsigned int *payload = (void *)udp + sizeof(*udp);
	if ((void *)payload + sizeof(unsigned int) > data_end)
		return XDP_PASS;

	// Note: In real world, check destination port too or scan all.
	// We scan all UDP packets!
	
	if (*payload == MAGIC_KNOCK) {
		// Redirect to Aether (AF_XDP Socket)
		return bpf_redirect_map(&xsks_map, ctx->rx_queue_index, 0);
	}

	// Else: Pass to Kernel (Web Server/Honeypot)
	return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
