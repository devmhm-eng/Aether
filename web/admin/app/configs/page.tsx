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
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "@/components/ui/select"

const PROTOCOLS = [
    { value: "flux", label: "Flux (uTLS)" },
    { value: "darkmatter", label: "Dark Matter" },
    { value: "nebula", label: "Nebula (IPv6)" },
    { value: "siren", label: "Siren" },
    { value: "websocket", label: "WebSocket" },
    { value: "grpc", label: "gRPC" },
    { value: "http", label: "HTTP" },
]

export default function ConfigsPage() {
    const [configs, setConfigs] = useState([])
    const [nodes, setNodes] = useState([])
    const [addDialogOpen, setAddDialogOpen] = useState(false)
    const [editDialogOpen, setEditDialogOpen] = useState(false)
    const [selectedConfig, setSelectedConfig] = useState<any>(null)
    const [formData, setFormData] = useState({
        name: "",
        node_id: "",
        protocols: [] as string[],
        auto: false,
        port: "443"
    })

    const fetchConfigs = () => {
        fetch('/api/configs').then(res => res.json()).then(data => setConfigs(data || []))
    }

    const fetchNodes = () => {
        fetch('/api/nodes').then(res => res.json()).then(data => setNodes(data || []))
    }

    useEffect(() => {
        fetchConfigs()
        fetchNodes()
    }, [])

    const toggleProtocol = (protocol: string) => {
        setFormData(prev => ({
            ...prev,
            protocols: prev.protocols.includes(protocol)
                ? prev.protocols.filter(p => p !== protocol)
                : [...prev.protocols, protocol]
        }))
    }

    const handleAdd = async () => {
        const protocolValue = formData.auto ? "auto" : formData.protocols.join(",")
        await fetch('/api/configs', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                name: formData.name,
                node_id: parseInt(formData.node_id),
                protocol: protocolValue,
                port: formData.port, // Send as string
                settings: JSON.stringify({ protocols: formData.auto ? ["auto"] : formData.protocols })
            })
        })
        setAddDialogOpen(false)
        setFormData({ name: "", node_id: "", protocols: [], auto: false, port: "443" })
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
                port: formData.port // Send as string
            })
        })
        setEditDialogOpen(false)
        fetchConfigs()
    }

    const handleDelete = async (id: number) => {
        if (confirm('Delete this config?')) {
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
                <h2 className="text-3xl font-bold tracking-tight">Core Configs</h2>
                <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
                    <DialogTrigger asChild>
                        <Button><Plus className="mr-2 h-4 w-4" /> Add Config</Button>
                    </DialogTrigger>
                    <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                        <DialogHeader>
                            <DialogTitle>Add New Config</DialogTitle>
                            <DialogDescription className="text-zinc-400">
                                Create a VPN configuration with multiple protocols.
                            </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label>Name</Label>
                                <Input className="bg-zinc-800 border-zinc-700" value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })} placeholder="Multi-Protocol Config" />
                            </div>
                            <div className="grid gap-2">
                                <Label>Node</Label>
                                <Select value={formData.node_id} onValueChange={(v) => setFormData({ ...formData, node_id: v })}>
                                    <SelectTrigger className="bg-zinc-800 border-zinc-700">
                                        <SelectValue placeholder="Select node" />
                                    </SelectTrigger>
                                    <SelectContent className="bg-zinc-800 border-zinc-700">
                                        {nodes.map((node: any) => (
                                            <SelectItem key={node.id} value={node.id.toString()}>{node.name}</SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </div>
                            <div className="grid gap-2">
                                <Label>Protocols (Select Multiple)</Label>
                                <div className="flex items-center space-x-2 mb-3 p-3 bg-zinc-800 rounded-md">
                                    <Checkbox id="auto" checked={formData.auto}
                                        onCheckedChange={(checked) => setFormData({ ...formData, auto: !!checked })} />
                                    <label htmlFor="auto" className="text-sm font-medium cursor-pointer">
                                        Auto (All Protocols) 🚀
                                    </label>
                                </div>
                                {!formData.auto && (
                                    <div className="grid grid-cols-2 gap-2">
                                        {PROTOCOLS.map(proto => (
                                            <div key={proto.value} className="flex items-center space-x-2 p-2 bg-zinc-800 rounded-md">
                                                <Checkbox
                                                    id={proto.value}
                                                    checked={formData.protocols.includes(proto.value)}
                                                    onCheckedChange={() => toggleProtocol(proto.value)}
                                                />
                                                <label htmlFor={proto.value} className="text-sm cursor-pointer">
                                                    {proto.label}
                                                </label>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>
                            <div className="grid gap-2">
                                <Label>Port</Label>
                                <Input type="number" className="bg-zinc-800 border-zinc-700" value={formData.port}
                                    onChange={(e) => setFormData({ ...formData, port: e.target.value })} />
                            </div>
                        </div>
                        <DialogFooter>
                            <Button onClick={handleAdd}>Create Config</Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </div>

            <div className="rounded-md border border-zinc-800 bg-zinc-900 text-white">
                <Table>
                    <TableHeader>
                        <TableRow className="border-zinc-800 hover:bg-zinc-800">
                            <TableHead>Name</TableHead>
                            <TableHead>Node</TableHead>
                            <TableHead>Protocols</TableHead>
                            <TableHead>Port</TableHead>
                            <TableHead>Status</TableHead>
                            <TableHead className="text-right">Actions</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {configs.map((config: any) => (
                            <TableRow key={config.id} className="border-zinc-800 hover:bg-zinc-800">
                                <TableCell className="font-medium">{config.name}</TableCell>
                                <TableCell>{config.node_name || 'N/A'}</TableCell>
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
                                <TableCell>
                                    <Badge className="bg-emerald-600">{config.status}</Badge>
                                </TableCell>
                                <TableCell className="text-right">
                                    <div className="flex justify-end gap-2">
                                        <Button variant="ghost" size="icon" onClick={() => {
                                            setSelectedConfig(config)
                                            const protocols = parseProtocols(config.protocol)
                                            setFormData({
                                                name: config.name,
                                                node_id: "",
                                                protocols: protocols[0] === "AUTO" ? [] : protocols,
                                                auto: protocols[0] === "AUTO",
                                                port: config.port.toString()
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
                                <TableCell colSpan={6} className="text-center text-zinc-500 py-8">
                                    No configs found. Create your first multi-protocol VPN configuration.
                                </TableCell>
                            </TableRow>
                        )}
                    </TableBody>
                </Table>
            </div>

            {/* Edit Dialog - Similar structure */}
            <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                    <DialogHeader>
                        <DialogTitle>Edit Config</DialogTitle>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                        <div className="grid gap-2">
                            <Label>Name</Label>
                            <Input className="bg-zinc-800 border-zinc-700" value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })} />
                        </div>
                        <div className="grid gap-2">
                            <Label>Protocols</Label>
                            <div className="flex items-center space-x-2 mb-3 p-3 bg-zinc-800 rounded-md">
                                <Checkbox id="auto-edit" checked={formData.auto}
                                    onCheckedChange={(checked) => setFormData({ ...formData, auto: !!checked })} />
                                <label htmlFor="auto-edit" className="text-sm font-medium cursor-pointer">
                                    Auto (All Protocols) 🚀
                                </label>
                            </div>
                            {!formData.auto && (
                                <div className="grid grid-cols-2 gap-2">
                                    {PROTOCOLS.map(proto => (
                                        <div key={proto.value} className="flex items-center space-x-2 p-2 bg-zinc-800 rounded-md">
                                            <Checkbox
                                                id={`edit-${proto.value}`}
                                                checked={formData.protocols.includes(proto.value)}
                                                onCheckedChange={() => toggleProtocol(proto.value)}
                                            />
                                            <label htmlFor={`edit-${proto.value}`} className="text-sm cursor-pointer">
                                                {proto.label}
                                            </label>
                                        </div>
                                    ))}
                                </div>
                            )}
                        </div>
                        <div className="grid gap-2">
                            <Label>Port</Label>
                            <Input type="number" className="bg-zinc-800 border-zinc-700" value={formData.port}
                                onChange={(e) => setFormData({ ...formData, port: e.target.value })} />
                        </div>
                    </div>
                    <DialogFooter>
                        <Button onClick={handleEdit}>Save Changes</Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    )
}
