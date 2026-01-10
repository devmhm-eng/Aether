"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Checkbox } from "@/components/ui/checkbox"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from "@/components/ui/dialog"
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Plus, Pencil, Trash2 } from "lucide-react"
import { Textarea } from "@/components/ui/textarea"

const PROTOCOLS = [
    { value: "vless", label: "VLESS Reality" },
    { value: "vmess", label: "VMess" },
    { value: "trojan", label: "Trojan" },
]

const SNIPPETS = {
    vless: `{
    "tag": "vless-reality",
    "listen": "0.0.0.0",
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [
        {
          "id": "uuid_placeholder",
          "flow": "xtls-rprx-vision"
        }
      ],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "www.google.com:443",
        "xver": 0,
        "serverNames": [
          "www.google.com"
        ],
        "privateKey": "replace_with_reality_private_key",
        "shortIds": [
          ""
        ]
      }
    }
  }`,
    vmess: `{
    "tag": "vmess-ws",
    "listen": "0.0.0.0",
    "port": 8080,
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "uuid_placeholder",
          "alterId": 0
        }
      ]
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/ws"
      }
    }
  }`,
    trojan: `{
    "tag": "trojan-tls",
    "listen": "0.0.0.0",
    "port": 8443,
    "protocol": "trojan",
    "settings": {
      "clients": [
        {
          "password": "password_placeholder"
        }
      ]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "tls",
      "tlsSettings": {
        "certificates": [
          {
            "certificateFile": "/path/to/cert.crt",
            "keyFile": "/path/to/key.key"
          }
        ]
      }
    }
  }`,
    shadowsocks: `{
    "tag": "ss-tcp",
    "listen": "0.0.0.0",
    "port": 1080,
    "protocol": "shadowsocks",
    "settings": {
      "method": "aes-256-gcm",
      "password": "password_placeholder",
      "network": "tcp,udp"
    }
  }`
}

export default function ConfigsPage() {
    const [configs, setConfigs] = useState([])
    const [addDialogOpen, setAddDialogOpen] = useState(false)
    const [editDialogOpen, setEditDialogOpen] = useState(false)
    const [selectedConfig, setSelectedConfig] = useState<any>(null)
    const [formData, setFormData] = useState({
        name: "",
        protocols: [] as string[],
        auto: false,
        port: "443",
        raw_inbounds: ""
    })

    const fetchConfigs = () => {
        fetch('/api/configs').then(res => res.json()).then(data => setConfigs(data || []))
    }

    useEffect(() => {
        fetchConfigs()
    }, [])

    const toggleProtocol = (protocol: string) => {
        setFormData(prev => ({
            ...prev,
            protocols: prev.protocols.includes(protocol)
                ? prev.protocols.filter(p => p !== protocol)
                : [...prev.protocols, protocol]
        }))
    }

    const addSnippet = (type: keyof typeof SNIPPETS) => {
        const snippet = SNIPPETS[type]
        let current = formData.raw_inbounds.trim()

        // Helper to format JSON nicely
        const format = (str: string) => {
            try { return JSON.stringify(JSON.parse(str), null, 2) }
            catch { return str }
        }

        if (!current) {
            // Start new array
            setFormData(prev => ({ ...prev, raw_inbounds: `[\n${snippet}\n]` }))
        } else {
            // Try to append to array
            if (current.startsWith('[') && current.endsWith(']')) {
                const content = current.slice(1, -1).trim() // Remove []
                const newContent = `[\n${content},\n${snippet}\n]`
                setFormData(prev => ({ ...prev, raw_inbounds: newContent })) // Simple append, user can format
            } else {
                // Not an array, wrap it? Or just append?
                // Provide simple append for now
                setFormData(prev => ({ ...prev, raw_inbounds: current + ",\n" + snippet }))
            }
        }
    }

    const handleAdd = async () => {
        const protocolValue = formData.auto ? "auto" : formData.protocols.join(",")
        await fetch('/api/configs', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                name: formData.name,
                protocol: protocolValue,
                port: formData.port,
                settings: JSON.stringify({ protocols: formData.auto ? ["auto"] : formData.protocols }),
                raw_inbounds: formData.raw_inbounds
            })
        })
        setAddDialogOpen(false)
        setFormData({ name: "", protocols: [], auto: false, port: "443", raw_inbounds: "" })
        fetchConfigs()
    }

    const handleEdit = async () => {
        const protocolValue = formData.auto ? "auto" : formData.protocols.join(",")
        await fetch('/api/configs', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                id: selectedConfig.id,
                name: formData.name,
                protocol: protocolValue,
                port: formData.port,
                raw_inbounds: formData.raw_inbounds
            })
        })
        setEditDialogOpen(false)
        fetchConfigs()
    }

    const handleDelete = async (id: number) => {
        if (confirm('Delete this Config Template?')) {
            await fetch(`/api/configs?id=${id}`, { method: 'DELETE' })
            fetchConfigs()
        }
    }

    const parseProtocols = (protocolStr: string) => {
        if (protocolStr === "auto") return ["AUTO"]
        return protocolStr?.split(",").filter(Boolean) || []
    }

    return (
        <div className="flex-1 space-y-4 p-8 pt-6">
            <div className="flex items-center justify-between">
                <div>
                    <h2 className="text-3xl font-bold tracking-tight">Configuration Templates</h2>
                    <p className="text-zinc-400 mt-2">Create inbound templates to reuse across multiple nodes.</p>
                </div>
                <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
                    <DialogTrigger asChild>
                        <Button><Plus className="mr-2 h-4 w-4" /> New Template</Button>
                    </DialogTrigger>
                    <DialogContent className="bg-zinc-900 border-zinc-800 text-white max-w-2xl max-h-[90vh] overflow-y-auto">
                        <DialogHeader>
                            <DialogTitle>Create Config Template</DialogTitle>
                            <DialogDescription className="text-zinc-400">
                                Define Xray inbounds. Paste full JSON array in "Raw Inbounds" for advanced use.
                            </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label>Template Name</Label>
                                <Input className="bg-zinc-800 border-zinc-700" value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })} placeholder="e.g., Standard VLESS Reality" />
                            </div>

                            {/* Raw Inbounds Editor */}
                            <div className="grid gap-2">
                                <div className="flex items-center justify-between">
                                    <Label className="text-emerald-400">Raw Inbounds (JSON Array/Object)</Label>
                                    <div className="flex gap-1">
                                        <Button size="sm" variant="outline" className="h-6 text-[10px] border-zinc-700" onClick={() => addSnippet('vless')}>+ VLESS</Button>
                                        <Button size="sm" variant="outline" className="h-6 text-[10px] border-zinc-700" onClick={() => addSnippet('vmess')}>+ VMess</Button>
                                        <Button size="sm" variant="outline" className="h-6 text-[10px] border-zinc-700" onClick={() => addSnippet('trojan')}>+ Trojan</Button>
                                        <Button size="sm" variant="outline" className="h-6 text-[10px] border-zinc-700" onClick={() => addSnippet('shadowsocks')}>+ SS</Button>
                                    </div>
                                </div>
                                <Textarea
                                    className="bg-zinc-950 border-zinc-700 font-mono text-xs h-60 text-green-400"
                                    value={formData.raw_inbounds}
                                    onChange={(e) => setFormData({ ...formData, raw_inbounds: e.target.value })}
                                    placeholder={`[\n  {\n    "listen": "0.0.0.0",\n    "port": 443,\n    ... \n  }\n]`}
                                />
                                <p className="text-xs text-zinc-500">
                                    Use the buttons above to insert templates. Supports multiple inbounds (JSON Array).
                                </p>
                            </div>
                        </div>
                        <DialogFooter>
                            <Button onClick={handleAdd}>Create Template</Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </div>

            <div className="rounded-md border border-zinc-800 bg-zinc-900 text-white">
                <Table>
                    <TableHeader>
                        <TableRow className="border-zinc-800 hover:bg-zinc-800">
                            <TableHead>Template Name</TableHead>
                            <TableHead>Assigned Nodes</TableHead>
                            <TableHead>Protocols (Meta)</TableHead>
                            <TableHead>Port</TableHead>
                            <TableHead className="text-right">Actions</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {configs.map((config: any) => (
                            <TableRow key={config.id} className="border-zinc-800 hover:bg-zinc-800">
                                <TableCell className="font-medium">
                                    <div className="flex flex-col">
                                        <span>{config.name}</span>
                                        {config.raw_inbounds && <span className="text-xs text-emerald-500 font-mono">RAW JSON ENABLED</span>}
                                    </div>
                                </TableCell>
                                <TableCell>
                                    <Badge variant="outline" className="border-zinc-700 text-zinc-300">
                                        {config.node_count || 0} Nodes
                                    </Badge>
                                </TableCell>
                                <TableCell>
                                    <div className="flex flex-wrap gap-1">
                                        {parseProtocols(config.protocol).map((p: string) => (
                                            <Badge key={p} className={p === "AUTO" ? "bg-purple-600" : "bg-blue-600"}>
                                                {p.toUpperCase()}
                                            </Badge>
                                        ))}
                                    </div>
                                </TableCell>
                                <TableCell>{config.port}</TableCell>
                                <TableCell className="text-right">
                                    <div className="flex justify-end gap-2">
                                        <Button variant="ghost" size="icon" onClick={() => {
                                            setSelectedConfig(config)
                                            const protocols = parseProtocols(config.protocol)
                                            setFormData({
                                                name: config.name,
                                                protocols: protocols[0] === "AUTO" ? [] : protocols,
                                                auto: protocols[0] === "AUTO",
                                                port: config.port.toString(),
                                                raw_inbounds: config.raw_inbounds || ""
                                            })
                                            setEditDialogOpen(true)
                                        }}>
                                            <Pencil className="h-4 w-4" />
                                        </Button>
                                        <Button variant="ghost" size="icon" onClick={() => handleDelete(config.id)}>
                                            <Trash2 className="h-4 w-4 text-red-500" />
                                        </Button>
                                    </div>
                                </TableCell>
                            </TableRow>
                        ))}
                        {configs.length === 0 && (
                            <TableRow>
                                <TableCell colSpan={5} className="text-center text-zinc-500 py-8">
                                    No templates found. Create your first Multi-Node Configuration Template.
                                </TableCell>
                            </TableRow>
                        )}
                    </TableBody>
                </Table>
            </div>

            {/* Edit Dialog */}
            <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white max-w-2xl max-h-[90vh] overflow-y-auto">
                    <DialogHeader>
                        <DialogTitle>Edit Template: {selectedConfig?.name}</DialogTitle>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                        <div className="grid gap-2">
                            <Label>Name</Label>
                            <Input className="bg-zinc-800 border-zinc-700" value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })} />
                        </div>
                        {/* Raw Inbounds Editor */}
                        <div className="grid gap-2">
                            <div className="flex items-center justify-between">
                                <Label className="text-emerald-400">Raw Inbounds (JSON)</Label>
                                <div className="flex gap-1">
                                    <Button size="sm" variant="outline" className="h-6 text-[10px] border-zinc-700" onClick={() => addSnippet('vless')}>+ VLESS</Button>
                                    <Button size="sm" variant="outline" className="h-6 text-[10px] border-zinc-700" onClick={() => addSnippet('vmess')}>+ VMess</Button>
                                    <Button size="sm" variant="outline" className="h-6 text-[10px] border-zinc-700" onClick={() => addSnippet('trojan')}>+ Trojan</Button>
                                    <Button size="sm" variant="outline" className="h-6 text-[10px] border-zinc-700" onClick={() => addSnippet('shadowsocks')}>+ SS</Button>
                                </div>
                            </div>
                            <Textarea
                                className="bg-zinc-950 border-zinc-700 font-mono text-xs h-60 text-green-400"
                                value={formData.raw_inbounds}
                                onChange={(e) => setFormData({ ...formData, raw_inbounds: e.target.value })}
                            />
                        </div>
                    </div>
                    <DialogFooter>
                        <Button onClick={handleEdit}>Update Template</Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    )
}
